--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Api = require(script.Parent.Api)
local Catalog = require(ReplicatedStorage.Catalog)
local Style = require(script.Parent.Style)

local ShopPanel = {}

function ShopPanel.new(gui: ScreenGui): Frame
	local panel, list = Style.panel(gui, "Shop")
	local refreshers: { () -> () } = {}

	for order, item in Catalog.Items do
		local _, detail, button = Style.row(list, order, item.Name)
		detail.Text = `{item.Slot} · {item.Price} coins`

		local function isOwned(): boolean
			local state = Api.state()
			return state ~= nil and state.OwnedItems[item.Id] == true
		end

		table.insert(refreshers, Api.bindButton(button, function()
			return if isOwned() then "Owned" else "Buy"
		end, function()
			return Api.call("BuyItem", item.Id)
		end))
	end

	Api.onState(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)

	return panel
end

return ShopPanel
