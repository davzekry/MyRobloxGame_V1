--!strict
-- Pure buy rules. They only read data and never yield, so a caller can check
-- and then spend in the same step without anything running in between.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResultCodes = require(ReplicatedStorage.ResultCodes)
local Types = require(ReplicatedStorage.Types)

local PurchaseRules = {}

function PurchaseRules.check(data: Types.PlayerData, item: Types.CatalogItem?): ResultCodes.ResultCode
	if item == nil then
		return ResultCodes.UnknownItem
	end
	if data.OwnedItems[item.Id] then
		return ResultCodes.AlreadyOwned
	end
	if data.Coins < item.Price then
		return ResultCodes.NotEnoughCoins
	end
	return ResultCodes.Ok
end

return PurchaseRules
