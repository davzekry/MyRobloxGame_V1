--!strict
-- The always-visible bar: balance plus buttons that open one panel at a time.
local Api = require(script.Parent.Api)
local Style = require(script.Parent.Style)

export type PanelEntry = {
	Name: string,
	Frame: Frame,
}

local BAR_HEIGHT = 40
local BAR_MAX_WIDTH = 560
local MAX_TEXT_SIZE = 18

local Hud = {}

-- Buttons share the bar's width, so four of them still fit on a phone held upright.
local function fitToBar(button: TextButton)
	button.Size = UDim2.new(0, 0, 1, 0)
	button.TextScaled = true

	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = button

	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = MAX_TEXT_SIZE
	textLimit.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
end

function Hud.new(gui: ScreenGui, panels: { PanelEntry })
	local bar = Instance.new("Frame")
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.new(0.96, 0, 0, BAR_HEIGHT)
	bar.BackgroundTransparency = 1

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BAR_MAX_WIDTH, BAR_HEIGHT)
	limit.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local balance = Style.button(bar, "...", true)
	balance.Name = "Balance"
	balance.Active = false
	balance.AutoButtonColor = false
	fitToBar(balance)
	Api.onState(function(state)
		balance.Text = `{state.Coins} coins`
	end)

	for order, entry in panels do
		local open = Style.button(bar, entry.Name)
		open.LayoutOrder = order
		fitToBar(open)
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
