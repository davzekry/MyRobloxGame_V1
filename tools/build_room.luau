-- Builds the demo room in Studio, replacing any earlier copy. Ctrl+Z undoes it in one step.
-- Run with: python tools/argon_exec.py <port> tools/build_room.luau
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local ROOM_NAME = "Room"
local ROOM_SIZE = 60
local WALL_HEIGHT = 12
local WALL_THICKNESS = 2
local FLOOR_COLOR = Color3.fromRGB(70, 75, 85)
local WALL_COLOR = Color3.fromRGB(45, 50, 60)

local PICKUP_TAG = "CoinPickup"
local PICKUP_COINS = 10
local PICKUP_COUNT = 8
local PICKUP_RING_RADIUS = 18
local PICKUP_SIZE = 3
local PICKUP_HEIGHT = 3
local PICKUP_COLOR = Color3.fromRGB(255, 200, 40)

local function addPart(room: Model, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = room
	return part
end

local function addWalls(room: Model)
	local offset = (ROOM_SIZE + WALL_THICKNESS) / 2
	local length = ROOM_SIZE + WALL_THICKNESS * 2
	local height = WALL_HEIGHT / 2

	addPart(room, "WallNorth", Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(0, height, -offset), WALL_COLOR)
	addPart(room, "WallSouth", Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(0, height, offset), WALL_COLOR)
	addPart(room, "WallEast", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE), Vector3.new(offset, height, 0), WALL_COLOR)
	addPart(room, "WallWest", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE), Vector3.new(-offset, height, 0), WALL_COLOR)
end

local function addPickups(room: Model)
	for index = 1, PICKUP_COUNT do
		local angle = (index - 1) / PICKUP_COUNT * math.pi * 2
		local position = Vector3.new(math.cos(angle) * PICKUP_RING_RADIUS, PICKUP_HEIGHT, math.sin(angle) * PICKUP_RING_RADIUS)

		local pickup = addPart(room, "CoinPickup", Vector3.one * PICKUP_SIZE, position, PICKUP_COLOR)
		pickup.Shape = Enum.PartType.Ball
		pickup.Material = Enum.Material.Neon
		pickup.CanCollide = false
		pickup:SetAttribute("Coins", PICKUP_COINS)
		CollectionService:AddTag(pickup, PICKUP_TAG)
	end
end

local recording = ChangeHistoryService:TryBeginRecording("Claude: build demo room")
assert(recording, "[Room] ChangeHistoryService could not start a recording")

local existing = workspace:FindFirstChild(ROOM_NAME)
if existing then
	existing:Destroy()
end

local room = Instance.new("Model")
room.Name = ROOM_NAME
addPart(room, "Floor", Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), Vector3.zero, FLOOR_COLOR)
addWalls(room)
addPickups(room)
room.Parent = workspace

ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
