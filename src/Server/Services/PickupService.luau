--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Services.EconomyService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local PICKUP_TAG = "CoinPickup"
local COINS_ATTRIBUTE = "Coins"
local RANGE_STUDS = 12
local RESPAWN_SECONDS = 15

local PickupService = {}

local inactive: { [BasePart]: boolean } = {}

local function setHidden(pickup: BasePart, hidden: boolean)
	pickup.Transparency = if hidden then 1 else 0
	pickup.CanTouch = not hidden
end

local function respawn(pickup: BasePart)
	setHidden(pickup, false)
	inactive[pickup] = nil
end

local function onTouched(pickup: BasePart, hit: BasePart)
	if inactive[pickup] then
		return
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if character == nil or player == nil or PlayerDataService.GetData(player) == nil then
		return
	end

	-- Exploiters can fake touches from anywhere, so the server checks the real distance.
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if (root.Position - pickup.Position).Magnitude > RANGE_STUDS then
		return
	end

	local amount = pickup:GetAttribute(COINS_ATTRIBUTE)
	if typeof(amount) ~= "number" then
		return
	end

	-- Marked before awarding, so a second touch can't also count.
	inactive[pickup] = true
	setHidden(pickup, true)
	task.delay(RESPAWN_SECONDS, respawn, pickup)

	if EconomyService.Award(player, amount) then
		PlayerDataService.PushState(player)
	end
end

local function bindPickup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Touched:Connect(function(hit)
			onTouched(instance, hit)
		end)
	end
end

function PickupService.Init()
	CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(bindPickup)
	for _, instance in CollectionService:GetTagged(PICKUP_TAG) do
		bindPickup(instance)
	end
end

return PickupService
