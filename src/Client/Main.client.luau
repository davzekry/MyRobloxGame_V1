--!strict
local Players = game:GetService("Players")

local UI = script.Parent:WaitForChild("UI")
local Api = require(UI:WaitForChild("Api"))
local Hud = require(UI:WaitForChild("Hud"))
local InventoryPanel = require(UI:WaitForChild("InventoryPanel"))
local ShopPanel = require(UI:WaitForChild("ShopPanel"))
local StressPanel = require(UI:WaitForChild("StressPanel"))

local gui = Instance.new("ScreenGui")
gui.Name = "CrateShop"
gui.ResetOnSpawn = false
-- Keeps the HUD clear of Roblox's own top bar and phone notches.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

Api.init()
Hud.new(gui, {
	{ Name = "Shop", Frame = ShopPanel.new(gui) },
	{ Name = "Inventory", Frame = InventoryPanel.new(gui) },
	{ Name = "Stress Test", Frame = StressPanel.new(gui) },
})
