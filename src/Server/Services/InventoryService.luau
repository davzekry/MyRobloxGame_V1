--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Catalog)
local CosmeticService = require(ServerScriptService.Services.CosmeticService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local RequestGate = require(ServerScriptService.RequestGate)
local RequestRules = require(ServerScriptService.Rules.RequestRules)
local ResultCodes = require(ReplicatedStorage.ResultCodes)

local InventoryService = {}

-- Doesn't yield, so ShopService can spend and grant in one step.
function InventoryService.Grant(player: Player, itemId: string): boolean
	local data = PlayerDataService.GetData(player)
	if data == nil then
		return false
	end

	data.OwnedItems[itemId] = true
	return true
end

local function setEquipped(player: Player, itemId: unknown, equipped: unknown): (ResultCodes.ResultCode, unknown)
	if not RequestRules.isItemId(itemId) or typeof(equipped) ~= "boolean" then
		return ResultCodes.InvalidRequest, itemId
	end

	local data = PlayerDataService.GetData(player)
	if data == nil then
		return ResultCodes.NotReady, itemId
	end

	local item = Catalog.get(itemId)
	if item == nil then
		return ResultCodes.UnknownItem, itemId
	end
	if not data.OwnedItems[item.Id] then
		return ResultCodes.NotOwned, itemId
	end

	-- Each slot holds one item, so equipping replaces whatever was in that slot.
	if equipped then
		data.EquippedItems[item.Slot] = item.Id
	elseif data.EquippedItems[item.Slot] == item.Id then
		data.EquippedItems[item.Slot] = nil
	end

	CosmeticService.Apply(player)
	PlayerDataService.PushState(player)
	return ResultCodes.Ok, itemId
end

function InventoryService.Init()
	RequestGate.bind("SetEquipped", 2, setEquipped)
end

return InventoryService
