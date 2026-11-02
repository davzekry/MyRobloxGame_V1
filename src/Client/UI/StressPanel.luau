--!strict
-- Lets an owner try to break the system. Every button fires the same remotes normal players use.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Api = require(script.Parent.Api)
local Catalog = require(ReplicatedStorage.Catalog)
local ResultCodes = require(ReplicatedStorage.ResultCodes)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Types)

local BURST_SIZE = 50
local STATE_SETTLE_SECONDS = 0.5
local FEED_LENGTH = 8

type CheatTest = {
	Name: string,
	Expect: string,
	Run: () -> string,
}

local CHEATS: { CheatTest } = {
	{
		Name = "Buy for 0 coins",
		Expect = "Sends BuyItem(\"crate_hat\", 0). Expect InvalidRequest.",
		Run = function()
			return Api.call("BuyItem", "crate_hat", 0)
		end,
	},
	{
		Name = "Unknown item",
		Expect = "Sends BuyItem(\"free_robux\"). Expect UnknownItem.",
		Run = function()
			return Api.call("BuyItem", "free_robux")
		end,
	},
	{
		Name = "Wrong type",
		Expect = "Sends BuyItem(12345). Expect InvalidRequest.",
		Run = function()
			return Api.call("BuyItem", 12345)
		end,
	},
	{
		Name = "Give me 1,000,000 coins",
		Expect = "A decoy remote that exists only for this demo. Expect Forbidden.",
		Run = function()
			return Api.call("AddCoins", 1000000)
		end,
	},
}

local StressPanel = {}

local function priceOf(itemIds: { string }): number
	local total = 0
	for _, itemId in itemIds do
		local item = Catalog.get(itemId)
		total += if item then item.Price else 0
	end
	return total
end

-- Fires 50 buys at once across every item, then checks that coins spent equal the
-- price of what was actually bought and the balance never went below zero.
local function runBurst(receipt: TextLabel): string
	local before = Api.state()
	if before == nil then
		return ResultCodes.NotReady
	end
	local beforeCoins = before.Coins
	local beforeOwned = table.clone(before.OwnedItems)

	local counts: { [string]: number } = {}
	local remaining = BURST_SIZE
	for index = 1, BURST_SIZE do
		local item = Catalog.Items[(index - 1) % #Catalog.Items + 1]
		task.spawn(function()
			local code = Api.call("BuyItem", item.Id)
			counts[code] = (counts[code] or 0) + 1
			remaining -= 1
		end)
	end
	while remaining > 0 do
		task.wait()
	end
	task.wait(STATE_SETTLE_SECONDS)

	local after = Api.state() :: Types.PlayerState
	local bought = {}
	for itemId in after.OwnedItems do
		if not beforeOwned[itemId] then
			table.insert(bought, itemId)
		end
	end

	local spent = beforeCoins - after.Coins
	local passed = spent == priceOf(bought) and after.Coins >= 0
	local codeLines = {}
	for code, count in counts do
		table.insert(codeLines, `{code} x{count}`)
	end
	table.sort(codeLines)

	receipt.Text = table.concat({
		if passed then "PASS" else "FAIL",
		`Balance {beforeCoins} -> {after.Coins} (spent {spent})`,
		`Bought: {if #bought > 0 then table.concat(bought, ", ") else "nothing"} (worth {priceOf(bought)})`,
		`Results: {table.concat(codeLines, ", ")}`,
	}, "\n")
	receipt.TextColor3 = if passed then Style.Colors.Accent else Color3.fromRGB(255, 110, 110)
	return ResultCodes.Ok
end

function StressPanel.new(gui: ScreenGui): Frame
	local panel, list = Style.panel(gui, "Stress Test")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local banner = Style.note(list, nextOrder(), "Saving is off, so the Rejoin test can't pass here.", true)
	banner.TextColor3 = Color3.fromRGB(255, 110, 110)
	banner.Visible = false
	Api.onState(function(state)
		banner.Visible = not state.SavingEnabled
	end)

	Style.note(list, nextOrder(), "Cheat attempts", true)
	for _, cheat in CHEATS do
		local _, detail, button = Style.row(list, nextOrder(), cheat.Name)
		detail.Text = cheat.Expect
		detail.TextScaled = true
		Api.bindButton(button, function()
			return "Run"
		end, cheat.Run)
	end

	Style.note(list, nextOrder(), "Double-spend", true)
	local _, burstDetail, burstButton = Style.row(list, nextOrder(), `Fire {BURST_SIZE} buys at once`)
	burstDetail.Text = "Spent must equal the price of what was bought."
	burstDetail.TextScaled = true
	local receipt = Style.note(list, nextOrder(), "")
	Api.bindButton(burstButton, function()
		return "Run"
	end, function()
		return runBurst(receipt)
	end)

	Style.note(list, nextOrder(), "Manual tests", true)
	Style.note(list, nextOrder(), "Rejoin: buy something, leave, and come back. Your items and balance should still be here.")
	Style.note(
		list,
		nextOrder(),
		"Duplicate session: join on a second device while playing. Roblox drops the first session, and nothing is lost or duplicated."
	)

	local _, resetDetail, resetButton = Style.row(list, nextOrder(), "Reset my data")
	resetDetail.Text = "Back to 250 coins and no items."
	resetDetail.TextScaled = true
	Api.bindButton(resetButton, function()
		return "Reset"
	end, function()
		return Api.call("ResetMyData")
	end)

	Style.note(list, nextOrder(), "Rejected requests", true)
	local feed = Style.note(list, nextOrder(), "None yet.")
	local entries: { string } = {}
	Api.onRejection(function(entry)
		table.insert(entries, 1, `{entry.Remote}: {entry.Code}{if entry.ItemId then ` ({entry.ItemId})` else ""}`)
		if #entries > FEED_LENGTH then
			table.remove(entries)
		end
		feed.Text = table.concat(entries, "\n")
	end)

	return panel
end

return StressPanel
