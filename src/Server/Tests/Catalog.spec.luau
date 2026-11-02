--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Catalog)

local VALID_SLOTS = { Hat = true, Trail = true, Color = true }

return {
	["ids are unique"] = function()
		local seen = {}
		for _, item in Catalog.Items do
			assert(seen[item.Id] == nil, `duplicate id {item.Id}`)
			seen[item.Id] = true
		end
	end,

	["prices are positive"] = function()
		for _, item in Catalog.Items do
			assert(item.Price > 0, `{item.Id} has a price of {item.Price}`)
		end
	end,

	["slots are valid"] = function()
		for _, item in Catalog.Items do
			assert(VALID_SLOTS[item.Slot], `{item.Id} has slot {item.Slot}`)
		end
	end,

	["items match the spec"] = function()
		local hat = Catalog.get("crate_hat")
		local trail = Catalog.get("spark_trail")
		local color = Catalog.get("gold_color")

		assert(#Catalog.Items == 3, "catalog should have 3 items")
		assert(hat and hat.Price == 100 and hat.Slot == "Hat", "crate_hat is wrong")
		assert(trail and trail.Price == 150 and trail.Slot == "Trail", "spark_trail is wrong")
		assert(color and color.Price == 200 and color.Slot == "Color", "gold_color is wrong")
	end,

	["get returns nil for an unknown id"] = function()
		assert(Catalog.get("free_robux") == nil, "unknown id should be nil")
	end,

	["get returns nil for a non-string"] = function()
		assert(Catalog.get(12345) == nil, "number should be nil")
		assert(Catalog.get(nil) == nil, "nil should be nil")
	end,
}
