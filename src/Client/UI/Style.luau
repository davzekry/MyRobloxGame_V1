--!strict
-- Shared look for every screen, like a small component library.

local Style = {}

Style.Colors = {
	Background = Color3.fromRGB(22, 26, 34),
	Surface = Color3.fromRGB(38, 44, 56),
	Accent = Color3.fromRGB(255, 200, 40),
	Text = Color3.fromRGB(240, 242, 246),
	Muted = Color3.fromRGB(160, 168, 182),
	OnAccent = Color3.fromRGB(30, 26, 14),
}

local BOLD = Enum.Font.BuilderSansBold
local REGULAR = Enum.Font.BuilderSans
local CORNER_RADIUS = 10
local PANEL_MAX_SIZE = Vector2.new(420, 520)
local PADDING = 12
local ROW_HEIGHT = 56
local BUTTON_SIZE = UDim2.fromOffset(120, 40)

local function round(instance: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	corner.Parent = instance
end

local function pad(instance: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, pixels)
	end
	padding.Parent = instance
end

function Style.label(parent: Instance, text: string, textSize: number, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then BOLD else REGULAR
	label.TextSize = textSize
	label.TextColor3 = Style.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function Style.button(parent: Instance, text: string, accent: boolean?): TextButton
	local button = Instance.new("TextButton")
	button.Size = BUTTON_SIZE
	button.BackgroundColor3 = if accent then Style.Colors.Accent else Style.Colors.Surface
	button.TextColor3 = if accent then Style.Colors.OnAccent else Style.Colors.Text
	button.Font = BOLD
	button.TextSize = 18
	button.Text = text
	round(button)
	button.Parent = parent
	return button
end

-- A centered, hidden window with a title, a close button, and a scrolling list for rows.
function Style.panel(gui: ScreenGui, title: string): (Frame, ScrollingFrame)
	local panel = Instance.new("Frame")
	panel.Name = title
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.75)
	panel.BackgroundColor3 = Style.Colors.Background
	panel.Visible = false
	round(panel)
	pad(panel, PADDING)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = PANEL_MAX_SIZE
	limit.Parent = panel

	local heading = Style.label(panel, title, 24, true)
	heading.Size = UDim2.new(1, -50, 0, 36)

	local close = Style.button(panel, "X")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(40, 36)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 48)
	list.Size = UDim2.new(1, 0, 1, -48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	panel.Parent = gui
	return panel, list
end

-- One list row with a title, a detail line, and a button on the right.
function Style.row(list: ScrollingFrame, order: number, title: string): (Frame, TextLabel, TextButton)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Style.Colors.Surface
	round(row)
	pad(row, 8)

	local name = Style.label(row, title, 18, true)
	name.Size = UDim2.new(1, -BUTTON_SIZE.X.Offset - 8, 0.5, 0)

	local detail = Style.label(row, "", 15)
	detail.Position = UDim2.fromScale(0, 0.5)
	detail.Size = name.Size
	detail.TextColor3 = Style.Colors.Muted

	local button = Style.button(row, "", true)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)

	row.Parent = list
	return row, detail, button
end

return Style
