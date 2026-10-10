local RateLimiter = require("../src/server/RateLimiter")
local T = require("./TestKit")

local function fakeClock()
	local now = 0
	return function()
		return now
	end, function(seconds: number)
		now += seconds
	end
end

return {
	["allows a burst up to capacity, then refuses"] = function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(3, 1, clock)
		T.truthy(limiter:Allow("p"))
		T.truthy(limiter:Allow("p"))
		T.truthy(limiter:Allow("p"))
		T.falsy(limiter:Allow("p"))
	end,
	["refills at the configured rate, capped at capacity"] = function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(2, 4, clock)
		T.truthy(limiter:Allow("p"))
		T.truthy(limiter:Allow("p"))
		T.falsy(limiter:Allow("p"))
		advance(0.25) -- one token
		T.truthy(limiter:Allow("p"))
		T.falsy(limiter:Allow("p"))
		advance(100)
		T.truthy(limiter:Allow("p"))
		T.truthy(limiter:Allow("p"))
		T.falsy(limiter:Allow("p"))
	end,
	["keeps separate buckets per key and forgets on request"] = function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(1, 1, clock)
		T.truthy(limiter:Allow("a"))
		T.falsy(limiter:Allow("a"))
		T.truthy(limiter:Allow("b"))
		limiter:Forget("a")
		T.equal(limiter.buckets["a"], nil)
		T.truthy(limiter:Allow("a"))
	end,
}
