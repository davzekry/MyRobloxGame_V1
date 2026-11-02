--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Types)

local items: { Types.CatalogItem } = {
	{ Id = "crate_hat", Name = "Crate Hat", Slot = "Hat", Price = 100 },
	{ Id = "spark_trail", Name = "Spark Trail", Slot = "Trail", Price = 150 },
	{ Id = "gold_color", Name = "Gold Color", Slot = "Color", Price = 200 },
}

local itemsById: { [string]: Types.CatalogItem } = {}
for _, item in items do
	itemsById[item.Id] = item
end

local Catalog = {
	Items = items,
}

function Catalog.get(id: unknown): Types.CatalogItem?
	if typeof(id) ~= "string" then
		return nil
	end
	return itemsById[id]
end

return Catalog
