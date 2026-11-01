--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PickupService = require(ServerScriptService.Services.PickupService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Remotes = require(ReplicatedStorage.Remotes)

Remotes.init()
PlayerDataService.Init()
PickupService.Init()
