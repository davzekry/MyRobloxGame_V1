--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Catalog)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local PurchaseRules = require(ServerScriptService.Rules.PurchaseRules)
local RequestGate = require(ServerScriptService.RequestGate)
local RequestRules = require(ServerScriptService.Rules.RequestRules)
local ResultCodes = require(ReplicatedStorage.ResultCodes)

local ShopService = {}

local function buyItem(player: Player, itemId: unknown): (ResultCodes.ResultCode, unknown)
	if not RequestRules.isItemId(itemId) then
		return ResultCodes.InvalidRequest, itemId
	end

	local data = PlayerDataService.GetData(player)
	if data == nil then
		return ResultCodes.NotReady, itemId
	end

	-- The price comes from the server's catalog. The client only ever sends an id.
	local item = Catalog.get(itemId)
	local code = PurchaseRules.check(data, item)
	if code ~= ResultCodes.Ok or item == nil then
		return code, itemId
	end

	-- No yield from the checks above to the end of Grant. A yield here would let a second
	-- request pass the same checks before this one spends, which is a double-spend.
	if not EconomyService.Spend(player, item.Price) then
		return ResultCodes.NotEnoughCoins, itemId
	end
	InventoryService.Grant(player, item.Id)

	PlayerDataService.PushState(player)
	return ResultCodes.Ok, itemId
end

function ShopService.Init()
	RequestGate.bind("BuyItem", 1, buyItem)
end

return ShopService
