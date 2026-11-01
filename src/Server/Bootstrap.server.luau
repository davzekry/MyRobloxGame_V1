--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DevCoins = require(ServerScriptService.DevCoins)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Remotes = require(ReplicatedStorage.Remotes)

Remotes.init()
PlayerDataService.Init()
DevCoins.Init()
