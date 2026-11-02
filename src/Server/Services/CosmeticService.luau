--!strict
-- Puts equipped items on the character. Items are built from basic shapes, so no art assets.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local COSMETIC_TAG = "CrateShopCosmetic"
local GOLD = Color3.fromRGB(255, 200, 40)
local CRATE_BROWN = Color3.fromRGB(150, 105, 60)
local TRAIL_START = Color3.fromRGB(120, 220, 255)
local TRAIL_END = Color3.fromRGB(255, 120, 230)
local BODY_COLOR_PROPERTIES = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

local CosmeticService = {}

-- Each character's own colors, saved before Gold Color first changes them.
local originalColors: { [BodyColors]: { [string]: Color3 } } = setmetatable({}, { __mode = "k" }) :: any

local function tag(instance: Instance)
	CollectionService:AddTag(instance, COSMETIC_TAG)
end

local function addHat(character: Model)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local hat = Instance.new("Part")
	hat.Name = "CrateHat"
	hat.Size = Vector3.new(1.4, 1, 1.4)
	hat.Color = CRATE_BROWN
	hat.Material = Enum.Material.WoodPlanks
	hat.Massless = true
	hat.CanCollide = false
	hat.CanQuery = false
	hat.CanTouch = false
	hat.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + hat.Size.Y / 2, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hat
	weld.Parent = hat

	tag(hat)
	hat.Parent = character
end

local function addTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "SparkTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(TRAIL_START, TRAIL_END)
	trail.Parent = root

	for _, instance in { top, bottom, trail } do
		tag(instance)
	end
end

local function setGold(character: Model, gold: boolean)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors == nil then
		return
	end

	local saved = originalColors[bodyColors]
	if saved == nil then
		saved = {}
		for _, property in BODY_COLOR_PROPERTIES do
			saved[property] = (bodyColors :: any)[property]
		end
		originalColors[bodyColors] = saved
	end

	for _, property in BODY_COLOR_PROPERTIES do
		(bodyColors :: any)[property] = if gold then GOLD else saved[property]
	end
end

local BUILDERS: { [string]: (Model) -> () } = {
	crate_hat = addHat,
	spark_trail = addTrail,
	gold_color = function(character)
		setGold(character, true)
	end,
}

-- Clears and rebuilds everything, so it's safe to call any number of times.
function CosmeticService.Apply(player: Player)
	local character = player.Character
	if character == nil then
		return
	end

	for _, instance in character:GetDescendants() do
		if CollectionService:HasTag(instance, COSMETIC_TAG) then
			instance:Destroy()
		end
	end
	setGold(character, false)

	local data = PlayerDataService.GetData(player)
	if data == nil then
		return
	end
	for _, itemId in data.EquippedItems do
		local build = BUILDERS[itemId]
		if build then
			build(character)
		end
	end
end

local function watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		CosmeticService.Apply(player)
	end)
end

function CosmeticService.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- The character can load before the profile, so apply again once data arrives.
	PlayerDataService.OnProfileLoaded(CosmeticService.Apply)
end

return CosmeticService
