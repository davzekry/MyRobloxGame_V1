--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Catalog)
local DataTemplate = require(ServerScriptService.Rules.DataTemplate)
local PurchaseRules = require(ServerScriptService.Rules.PurchaseRules)
local ResultCodes = require(ReplicatedStorage.ResultCodes)

local HAT = Catalog.get("crate_hat")
assert(HAT, "crate_hat is missing from the catalog")

local function dataWithCoins(coins: number)
	local data = DataTemplate.new()
	data.Coins = coins
	return data
end

return {
	["enough coins is Ok"] = function()
		assert(PurchaseRules.check(dataWithCoins(250), HAT) == ResultCodes.Ok, "250 coins should buy a 100-coin hat")
	end,

	["exact coins is Ok"] = function()
		assert(PurchaseRules.check(dataWithCoins(HAT.Price), HAT) == ResultCodes.Ok, "exact price should be Ok")
	end,

	["one coin short is NotEnoughCoins"] = function()
		local result = PurchaseRules.check(dataWithCoins(HAT.Price - 1), HAT)
		assert(result == ResultCodes.NotEnoughCoins, `expected NotEnoughCoins, got {result}`)
	end,

	["already owned is AlreadyOwned"] = function()
		local data = dataWithCoins(250)
		data.OwnedItems[HAT.Id] = true
		local result = PurchaseRules.check(data, HAT)
		assert(result == ResultCodes.AlreadyOwned, `expected AlreadyOwned, got {result}`)
	end,

	["nil item is UnknownItem"] = function()
		local result = PurchaseRules.check(dataWithCoins(250), nil)
		assert(result == ResultCodes.UnknownItem, `expected UnknownItem, got {result}`)
	end,

	["owned wins over short of coins"] = function()
		local data = dataWithCoins(0)
		data.OwnedItems[HAT.Id] = true
		local result = PurchaseRules.check(data, HAT)
		assert(result == ResultCodes.AlreadyOwned, `expected AlreadyOwned, got {result}`)
	end,

	["check never changes data"] = function()
		local data = dataWithCoins(250)
		PurchaseRules.check(data, HAT)
		assert(data.Coins == 250 and data.OwnedItems[HAT.Id] == nil, "check should only read")
	end,
}
