-- Headless unit tests for the pure RateLimiter. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local RateLimiter = require("../src/server/Net/RateLimiter")

local passed = 0
local failed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print("  FAIL: " .. name)
	end
end

-- Burst: capacity tokens allowed, then rejected while the clock is frozen.
do
	local rl = RateLimiter.new({ capacity = 3, refillPerSecond = 1 })
	check("allows first token", rl:allow("a", 0))
	check("allows second token", rl:allow("a", 0))
	check("allows third token (capacity)", rl:allow("a", 0))
	check("rejects fourth token at capacity", not rl:allow("a", 0))
end

-- Refill: after enough elapsed time a rejected key is allowed again.
do
	local rl = RateLimiter.new({ capacity = 1, refillPerSecond = 2 })
	check("first token allowed", rl:allow("a", 0))
	check("immediate second rejected", not rl:allow("a", 0))
	check("half second refills one token", rl:allow("a", 0.5))
	check("drained again immediately", not rl:allow("a", 0.5))
end

-- Refill is capped at capacity: a long idle does not grant more than a burst.
do
	local rl = RateLimiter.new({ capacity = 2, refillPerSecond = 100 })
	check("burst 1", rl:allow("a", 0))
	check("burst 2", rl:allow("a", 0))
	-- 10s * 100/s would be 1000 tokens, but capacity caps it at 2.
	check("cap grant 1 after long idle", rl:allow("a", 10))
	check("cap grant 2 after long idle", rl:allow("a", 10))
	check("no third token beyond capacity", not rl:allow("a", 10))
end

-- Keys are independent buckets.
do
	local rl = RateLimiter.new({ capacity = 1, refillPerSecond = 0 })
	check("key a allowed", rl:allow("a", 0))
	check("key b independent of a", rl:allow("b", 0))
	check("key a now drained", not rl:allow("a", 0))
end

-- clearPrefix drops matching buckets so they refill to full on next use.
do
	local rl = RateLimiter.new({ capacity = 1, refillPerSecond = 0 })
	check("drain 1:cast", rl:allow("1:cast", 0))
	check("drain 2:cast", rl:allow("2:cast", 0))
	check("1:cast drained", not rl:allow("1:cast", 0))
	rl:clearPrefix("1:")
	check("1:cast full again after clearPrefix", rl:allow("1:cast", 0))
	check("2:cast untouched by clearPrefix('1:')", not rl:allow("2:cast", 0))
end

-- Defensive config clamping: capacity floored to 1, negative refill floored to 0.
do
	local rl = RateLimiter.new({ capacity = 0, refillPerSecond = -5 })
	check("capacity floored to at least 1", rl:allow("a", 0))
	check("no refill with clamped rate", not rl:allow("a", 100))
end

return { passed = passed, failed = failed }
