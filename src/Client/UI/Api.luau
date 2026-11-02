--!strict
-- The client's only way to talk to the server. Screens read state from here and never
-- change it themselves: the server's StateChanged push is the single source of truth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local ResultCodes = require(ReplicatedStorage.ResultCodes)
local Types = require(ReplicatedStorage.Types)

local CALL_FAILED = "CallFailed"
local RESULT_SHOW_SECONDS = 2

local MESSAGES: { [string]: string } = {
	[CALL_FAILED] = "Try again",
	[ResultCodes.NotReady] = "Loading...",
	[ResultCodes.RateLimited] = "Slow down",
	[ResultCodes.InvalidRequest] = "Invalid request",
	[ResultCodes.UnknownItem] = "Unknown item",
	[ResultCodes.AlreadyOwned] = "Already owned",
	[ResultCodes.NotEnoughCoins] = "Not enough coins",
	[ResultCodes.NotOwned] = "Not owned",
	[ResultCodes.Forbidden] = "Refused",
}

local Api = {}

local currentState: Types.PlayerState? = nil
local stateListeners: { (Types.PlayerState) -> () } = {}

function Api.init()
	Remotes.event("StateChanged").OnClientEvent:Connect(function(state: Types.PlayerState)
		currentState = state
		for _, listener in stateListeners do
			task.spawn(listener, state)
		end
	end)
end

function Api.state(): Types.PlayerState?
	return currentState
end

function Api.onState(listener: (Types.PlayerState) -> ())
	table.insert(stateListeners, listener)
	if currentState then
		task.spawn(listener, currentState)
	end
end

-- Returns the server's result code, or "CallFailed" if the call itself errored.
function Api.call(name: string, ...: any): string
	local remote = Remotes.func(name)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok and typeof(result) == "string" then
		return result
	end
	return CALL_FAILED
end

-- Wires a button to a server call. It's disabled while waiting, shows the server's answer
-- for anything but Ok, and never shows success before the server confirms it.
-- Returns a refresh function for when state changes the label.
function Api.bindButton(button: TextButton, label: () -> string, action: () -> string): () -> ()
	local busy = false

	local function refresh()
		if not busy then
			button.Text = label()
		end
	end

	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		button.Active = false
		button.AutoButtonColor = false
		button.Text = "..."

		local result = action()

		busy = false
		button.Active = true
		button.AutoButtonColor = true
		if result == ResultCodes.Ok then
			refresh()
		else
			button.Text = MESSAGES[result] or result
			task.delay(RESULT_SHOW_SECONDS, refresh)
		end
	end)

	refresh()
	return refresh
end

return Api
