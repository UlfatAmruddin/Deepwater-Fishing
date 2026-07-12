--!strict
-- Deterministic seeded pseudo-random generator.
--
-- A small, portable linear congruential generator implemented in pure Luau
-- arithmetic — it does NOT use `Random` or the `math.random` global, so the same
-- seed always yields the same sequence in Roblox AND headlessly under Lune, and
-- tests never depend on global RNG state. Callers inject a seed (the server picks
-- an unpredictable one at run time in a later stage); layout generation stays
-- reproducible for a given seed.
--
-- Not cryptographic — just a reproducible stream for gameplay.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

local MODULUS = 4294967296 -- 2^32
local MULTIPLIER = 1664525
local INCREMENT = 1013904223

local function normalizeSeed(seed: number): number
	local s = math.floor(seed) % MODULUS
	if s < 0 then
		s += MODULUS
	end
	return s
end

function Rng.new(seed: number): Rng
	return setmetatable({ _state = normalizeSeed(seed) }, Rng)
end

-- Next value in [0, 1). MULTIPLIER * state (< 2^53) stays exact in a double.
function Rng.nextNumber(self: Rng): number
	self._state = (MULTIPLIER * self._state + INCREMENT) % MODULUS
	return self._state / MODULUS
end

-- Next integer in [min, max] (inclusive). Order-agnostic in its bounds.
function Rng.nextInteger(self: Rng, min: number, max: number): number
	if max < min then
		min, max = max, min
	end
	local span = max - min + 1
	return min + math.floor(Rng.nextNumber(self) * span)
end

-- Next float in [min, max).
function Rng.nextFloat(self: Rng, min: number, max: number): number
	return min + (max - min) * Rng.nextNumber(self)
end

return Rng
