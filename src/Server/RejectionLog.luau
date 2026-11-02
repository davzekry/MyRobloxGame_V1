--!strict
-- Keeps each player's recent rejections and tells their client, which feeds the Stress Test panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local Types = require(ReplicatedStorage.Types)

local MAX_ENTRIES = 50

local RejectionLog = {}

local entries: { [Player]: { Types.RejectionEntry } } = {}
local rejectionLogged: RemoteEvent

function RejectionLog.Init()
	rejectionLogged = Remotes.event("RejectionLogged")
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

function RejectionLog.add(player: Player, entry: Types.RejectionEntry)
	local playerEntries = entries[player] or {}
	entries[player] = playerEntries

	table.insert(playerEntries, entry)
	if #playerEntries > MAX_ENTRIES then
		table.remove(playerEntries, 1)
	end

	rejectionLogged:FireClient(player, entry)
end

function RejectionLog.recent(player: Player): { Types.RejectionEntry }
	return table.clone(entries[player] or {})
end

return RejectionLog
