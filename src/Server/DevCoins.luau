--!strict
-- Temporary Studio-only check for the Phase 1 saving test. Removed in Task 5.
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local COINS_PER_LOAD = 10

local DevCoins = {}

local function addCoins(player: Player)
	local data = PlayerDataService.GetData(player)
	if data == nil then
		return
	end

	data.Coins += COINS_PER_LOAD
	PlayerDataService.PushState(player)
	print(`[DevCoins] {player.Name} now has {data.Coins} coins`)
end

function DevCoins.Init()
	if RunService:IsStudio() then
		PlayerDataService.OnProfileLoaded(addCoins)
	end
end

return DevCoins
