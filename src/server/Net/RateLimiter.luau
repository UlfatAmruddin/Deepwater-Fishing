--!strict
-- Token-bucket rate limiter.
--
-- Pure logic with an INJECTED clock: `allow(key, now)` takes the current time, so
-- tests drive it deterministically and the server passes os.clock(). Buckets are
-- keyed by an arbitrary string (RemoteGuard uses "<userId>:<remoteName>") and
-- cleared per player on leave via clearPrefix. A leaf module -> headlessly
-- testable; it holds only its own bucket state.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, updatedAt: number }

export type Config = {
	capacity: number, -- max tokens (burst size)
	refillPerSecond: number, -- sustained tokens per second
}

export type RateLimiter = typeof(setmetatable(
	{} :: { _capacity: number, _refill: number, _buckets: { [string]: Bucket } },
	RateLimiter
))

function RateLimiter.new(config: Config): RateLimiter
	return setmetatable({
		_capacity = math.max(1, config.capacity),
		_refill = math.max(0, config.refillPerSecond),
		_buckets = {},
	}, RateLimiter)
end

-- Consume one token for `key` at time `now` (seconds). Returns true if allowed.
function RateLimiter.allow(self: RateLimiter, key: string, now: number): boolean
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, updatedAt = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.updatedAt)
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refill)
		bucket.updatedAt = now
	end
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Drop every bucket whose key starts with `prefix` (per-player cleanup on leave).
function RateLimiter.clearPrefix(self: RateLimiter, prefix: string)
	for key in self._buckets do
		if string.sub(key, 1, #prefix) == prefix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
