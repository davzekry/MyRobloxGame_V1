--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ServerScriptService.Rules.DataTemplate)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local Remotes = require(ReplicatedStorage.Remotes)
local Types = require(ReplicatedStorage.Types)

type Profile = ProfileStore.Profile<Types.PlayerData>

-- Studio shares data stores with the live game, so it gets its own store.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData_v1"
local LOAD_DEADLINE_SECONDS = 30
local RELEASE_POLL_SECONDS = 0.1
local REJOIN_MESSAGE = "We couldn't load your data, and nothing was changed. Please rejoin."
local SESSION_ENDED_MESSAGE = "Your data was opened on another server, so this session has ended. Please rejoin."

local PlayerDataService = {}

local store: ProfileStore.ProfileStore<Types.PlayerData>
local stateChanged: RemoteEvent
local profiles: { [Player]: Profile } = {}
local releasing: { [number]: Profile } = {}
local loadedCallbacks: { (Player) -> () } = {}

local function releaseProfile(userId: number, profile: Profile)
	releasing[userId] = profile

	-- OnSessionEnd fires before the final save is written, so wait for the save itself.
	-- A same-server rejoin before then would load the older saved copy.
	local connection
	connection = profile.OnAfterSave:Connect(function()
		connection:Disconnect()
		if releasing[userId] == profile then
			releasing[userId] = nil
		end
	end)

	profile:EndSession()
end

local function onSessionEnd(player: Player, profile: Profile)
	-- Changes to Data stop saving once a session ends, so stop handing it out first.
	if profiles[player] == profile then
		profiles[player] = nil
	end

	-- We ended it ourselves (the player left), or Roblox is disconnecting everyone during
	-- shutdown. Only a takeover by another server needs a message.
	if releasing[player.UserId] == profile or ProfileStore.IsClosing then
		return
	end
	if player.Parent == Players then
		player:Kick(SESSION_ENDED_MESSAGE)
	end
end

local function loadProfile(player: Player)
	local deadline = os.clock() + LOAD_DEADLINE_SECONDS

	-- Setting Cancel turns off ProfileStore's own timeout, so the deadline lives here.
	local function isCancelled(): boolean
		return player.Parent ~= Players or os.clock() > deadline
	end

	-- A player who quickly rejoins the same server waits for their final save to be written.
	while releasing[player.UserId] and not isCancelled() do
		task.wait(RELEASE_POLL_SECONDS)
	end

	local started, result = pcall(function()
		return store:StartSessionAsync(`Player_{player.UserId}`, { Cancel = isCancelled })
	end)
	if not started then
		warn(`[PlayerData] Load failed for {player.Name}: {result}`)
	end

	local profile: Profile? = if started then result else nil
	if profile == nil then
		if player.Parent == Players then
			player:Kick(REJOIN_MESSAGE)
		end
		return
	end

	profile.OnSessionEnd:Connect(function()
		onSessionEnd(player, profile)
	end)
	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if player.Parent ~= Players then
		releaseProfile(player.UserId, profile)
		return
	end

	profiles[player] = profile
	PlayerDataService.PushState(player)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		releaseProfile(player.UserId, profile)
	end
end

function PlayerDataService.Init()
	store = ProfileStore.New(STORE_NAME, DataTemplate.new())
	stateChanged = Remotes.event("StateChanged")

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Players who joined before this script ran don't fire PlayerAdded.
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

function PlayerDataService.GetData(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.PushState(player: Player)
	local data = PlayerDataService.GetData(player)
	if data == nil then
		return
	end

	local state: Types.PlayerState = {
		Coins = data.Coins,
		OwnedItems = data.OwnedItems,
		EquippedItems = data.EquippedItems,
		SavingEnabled = ProfileStore.DataStoreState == "Access",
	}
	stateChanged:FireClient(player, state)
end

function PlayerDataService.OnProfileLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
end

return PlayerDataService
