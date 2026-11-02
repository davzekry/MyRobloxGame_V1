--!strict
-- The only code that changes coins, apart from the demo-only reset in DemoService.
-- Nothing here yields, so a caller can check and spend safely.
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local EconomyService = {}

local function assertPositiveInteger(amount: number)
	assert(amount > 0 and math.floor(amount) == amount, "amount must be a positive integer")
end

function EconomyService.Award(player: Player, amount: number): boolean
	assertPositiveInteger(amount)

	local data = PlayerDataService.GetData(player)
	if data == nil then
		return false
	end

	data.Coins += amount
	return true
end

function EconomyService.Spend(player: Player, amount: number): boolean
	assertPositiveInteger(amount)

	local data = PlayerDataService.GetData(player)
	if data == nil or data.Coins < amount then
		return false
	end

	data.Coins -= amount
	return true
end

return EconomyService
