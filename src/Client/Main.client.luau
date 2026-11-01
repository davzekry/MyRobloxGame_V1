--!strict
-- Temporary: logs the pushed balance until the HUD arrives in Task 11.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local Types = require(ReplicatedStorage.Types)

Remotes.event("StateChanged").OnClientEvent:Connect(function(state: Types.PlayerState)
	print(`[State] {state.Coins} coins, saving={state.SavingEnabled}`)
end)
