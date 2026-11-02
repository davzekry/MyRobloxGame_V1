--!strict
-- The always-visible bar: balance plus buttons that open one panel at a time.
local Api = require(script.Parent.Api)
local Style = require(script.Parent.Style)

export type PanelEntry = {
	Name: string,
	Frame: Frame,
}

local Hud = {}

function Hud.new(gui: ScreenGui, panels: { PanelEntry })
	local bar = Instance.new("Frame")
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local balance = Style.button(bar, "...", true)
	balance.Name = "Balance"
	balance.Active = false
	balance.AutoButtonColor = false
	Api.onState(function(state)
		balance.Text = `{state.Coins} coins`
	end)

	for order, entry in panels do
		local open = Style.button(bar, entry.Name)
		open.LayoutOrder = order
		open.Activated:Connect(function()
			local wasOpen = entry.Frame.Visible
			for _, other in panels do
				other.Frame.Visible = false
			end
			entry.Frame.Visible = not wasOpen
		end)
	end

	bar.Parent = gui
end

return Hud
