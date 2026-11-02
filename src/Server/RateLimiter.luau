--!strict
-- A token bucket per key. Callers pass the current time, so tests control the clock.

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	return setmetatable({
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any, now: number): boolean
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.capacity, updatedAt = now }
		self.buckets[key] = bucket
	else
		local refilled = bucket.tokens + (now - bucket.updatedAt) * self.refillPerSecond
		bucket.tokens = math.min(self.capacity, refilled)
		bucket.updatedAt = now
	end

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
