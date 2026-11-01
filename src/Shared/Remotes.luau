--!strict

local FUNCTIONS = { "BuyItem", "SetEquipped", "ResetMyData", "AddCoins" }
local EVENTS = { "StateChanged", "RejectionLogged" }

local Remotes = {}

local function create(className: string, name: string)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = script
end

-- Server only. Remotes live under this module, so clients can reach them once they replicate.
function Remotes.init()
	for _, name in FUNCTIONS do
		create("RemoteFunction", name)
	end
	for _, name in EVENTS do
		create("RemoteEvent", name)
	end
end

function Remotes.func(name: string): RemoteFunction
	return script:WaitForChild(name) :: RemoteFunction
end

function Remotes.event(name: string): RemoteEvent
	return script:WaitForChild(name) :: RemoteEvent
end

return Remotes
