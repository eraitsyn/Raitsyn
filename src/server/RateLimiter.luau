--[[
	RateLimiter: one token bucket per player.

	Each player starts with `capacity` tokens and regains `perSecond` tokens a second,
	up to `capacity`. Allow() spends a token or returns false when none are left.
	The clock is injectable so this module can be unit tested outside Studio.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, stamp: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		perSecond: number,
		clock: () -> number,
		buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, perSecond: number, clock: (() -> number)?): RateLimiter
	assert(capacity >= 1, "capacity must be at least 1")
	assert(perSecond > 0, "perSecond must be positive")
	return setmetatable({
		capacity = capacity,
		perSecond = perSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.Allow(self: RateLimiter, key: any): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.capacity, stamp = now }
		self.buckets[key] = bucket
	else
		bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.stamp) * self.perSecond)
		bucket.stamp = now
	end
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
