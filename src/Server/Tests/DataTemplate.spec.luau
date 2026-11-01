--!strict
local DataTemplate = require(script.Parent.Parent.Rules.DataTemplate)

return {
	["new returns starting values"] = function()
		local data = DataTemplate.new()

		assert(data.Version == 1, "Version should be 1")
		assert(data.Coins == 250, "Coins should be 250")
		assert(next(data.OwnedItems) == nil, "OwnedItems should be empty")
		assert(next(data.EquippedItems) == nil, "EquippedItems should be empty")
	end,

	["new never shares tables"] = function()
		local first = DataTemplate.new()
		local second = DataTemplate.new()

		first.OwnedItems.crate_hat = true
		first.EquippedItems.Hat = "crate_hat"

		assert(second.OwnedItems.crate_hat == nil, "OwnedItems should not be shared")
		assert(second.EquippedItems.Hat == nil, "EquippedItems should not be shared")
	end,
}
