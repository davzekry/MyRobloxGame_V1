--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Api = require(script.Parent.Api)
local Catalog = require(ReplicatedStorage.Catalog)
local Style = require(script.Parent.Style)

local InventoryPanel = {}

function InventoryPanel.new(gui: ScreenGui): Frame
	local panel, list = Style.panel(gui, "Inventory")

	local empty = Style.label(list, "Nothing yet. Collect coins and visit the shop.", 16)
	empty.Size = UDim2.new(1, -8, 0, 40)
	empty.TextWrapped = true
	empty.TextColor3 = Style.Colors.Muted

	local rows: { [string]: Frame } = {}
	local refreshers: { () -> () } = {}

	for order, item in Catalog.Items do
		local row, detail, button = Style.row(list, order, item.Name)
		detail.Text = item.Slot
		rows[item.Id] = row

		local function isEquipped(): boolean
			local state = Api.state()
			return state ~= nil and state.EquippedItems[item.Slot] == item.Id
		end

		table.insert(refreshers, Api.bindButton(button, function()
			return if isEquipped() then "Unequip" else "Equip"
		end, function()
			return Api.call("SetEquipped", item.Id, not isEquipped())
		end))
	end

	Api.onState(function(state)
		local ownsAny = false
		for itemId, row in rows do
			row.Visible = state.OwnedItems[itemId] == true
			ownsAny = ownsAny or row.Visible
		end
		empty.Visible = not ownsAny

		for _, refresh in refreshers do
			refresh()
		end
	end)

	return panel
end

return InventoryPanel
