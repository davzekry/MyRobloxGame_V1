--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Types)

local DataTemplate = {}

function DataTemplate.new(): Types.PlayerData
	return {
		Version = 1,
		Coins = 250,
		OwnedItems = {},
		EquippedItems = {},
	}
end

return DataTemplate
