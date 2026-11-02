--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local RateLimiter = require(ServerScriptService.RateLimiter)

local CAPACITY = 10
local REFILL_PER_SECOND = 5

local function drain(limiter, key: string, now: number)
	for _ = 1, CAPACITY do
		assert(limiter:allow(key, now), "a request within capacity was refused")
	end
end

return {
	["first 10 pass"] = function()
		drain(RateLimiter.new(CAPACITY, REFILL_PER_SECOND), "a", 0)
	end,

	["11th is refused"] = function()
		local limiter = RateLimiter.new(CAPACITY, REFILL_PER_SECOND)
		drain(limiter, "a", 0)
		assert(not limiter:allow("a", 0), "the 11th request should be refused")
	end,

	["tokens refill over time"] = function()
		local limiter = RateLimiter.new(CAPACITY, REFILL_PER_SECOND)
		drain(limiter, "a", 0)
		assert(limiter:allow("a", 0.2), "one token should be back after 0.2 seconds")
		assert(not limiter:allow("a", 0.2), "only one token should be back")
	end,

	["tokens never exceed capacity"] = function()
		local limiter = RateLimiter.new(CAPACITY, REFILL_PER_SECOND)
		drain(limiter, "a", 100)
		assert(not limiter:allow("a", 100), "a long wait should still cap at 10")
	end,

	["players don't share buckets"] = function()
		local limiter = RateLimiter.new(CAPACITY, REFILL_PER_SECOND)
		drain(limiter, "a", 0)
		assert(limiter:allow("b", 0), "another player should have a full bucket")
	end,

	["forget resets a key"] = function()
		local limiter = RateLimiter.new(CAPACITY, REFILL_PER_SECOND)
		drain(limiter, "a", 0)
		limiter:forget("a")
		assert(limiter:allow("a", 0), "a forgotten key should start full")
	end,
}
