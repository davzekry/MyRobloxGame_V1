--!strict
-- Every client-called remote goes through here: rate limit, argument count, then the
-- handler, then logging. Like middleware in front of each API route.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RateLimiter = require(ServerScriptService.RateLimiter)
local RejectionLog = require(ServerScriptService.RejectionLog)
local RequestRules = require(ServerScriptService.Rules.RequestRules)
local Remotes = require(ReplicatedStorage.Remotes)
local ResultCodes = require(ReplicatedStorage.ResultCodes)

type ResultCode = ResultCodes.ResultCode
export type Handler = (Player, ...any) -> (ResultCode, any?)

local BUCKET_CAPACITY = 10
local REFILL_PER_SECOND = 5

local limiter = RateLimiter.new(BUCKET_CAPACITY, REFILL_PER_SECOND)

local RequestGate = {}

function RequestGate.Init()
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

-- expectedArgs = nil skips the argument count check (used by the AddCoins decoy).
function RequestGate.bind(name: string, expectedArgs: number?, handler: Handler)
	Remotes.func(name).OnServerInvoke = function(player: Player, ...: any): ResultCode
		if not limiter:allow(player, os.clock()) then
			-- Not logged, so spamming can't flood the log.
			return ResultCodes.RateLimited
		end

		local code: ResultCode, itemId: any
		if expectedArgs ~= nil and not RequestRules.hasExactArgs(select("#", ...), expectedArgs) then
			code, itemId = ResultCodes.InvalidRequest, (...)
		else
			code, itemId = handler(player, ...)
		end

		if code ~= ResultCodes.Ok then
			RejectionLog.add(player, {
				Code = code,
				Remote = name,
				ItemId = RequestRules.logSafeItemId(itemId),
			})
		end
		return code
	end
end

return RequestGate
