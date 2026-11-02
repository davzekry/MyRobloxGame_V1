--!strict
-- Demo-only remotes for the Stress Test panel. To add this system to another game,
-- delete this file and its line in Bootstrap; nothing else depends on it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticService = require(ServerScriptService.Services.CosmeticService)
local DataTemplate = require(ServerScriptService.Rules.DataTemplate)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local RequestGate = require(ServerScriptService.RequestGate)
local ResultCodes = require(ReplicatedStorage.ResultCodes)

local DemoService = {}

-- A decoy: a real game has no remote that grants coins, so this one only ever refuses.
local function addCoins(_player: Player, ...: any): ResultCodes.ResultCode
	return ResultCodes.Forbidden
end

-- Back to the starting state. It can't gain anything, because every item is lost too.
local function resetMyData(player: Player): ResultCodes.ResultCode
	local data = PlayerDataService.GetData(player)
	if data == nil then
		return ResultCodes.NotReady
	end

	-- Copy fields into the live table: the profile keeps its reference to it.
	for key, value in DataTemplate.new() do
		(data :: any)[key] = value
	end

	CosmeticService.Apply(player)
	PlayerDataService.PushState(player)
	return ResultCodes.Ok
end

function DemoService.Init()
	RequestGate.bind("AddCoins", nil, addCoins)
	RequestGate.bind("ResetMyData", 0, resetMyData)
end

return DemoService
