--!strict
-- Pure numeric helpers with no Roblox dependencies, so they can be unit-tested
-- headlessly under Lune (see tests/).

local Math = {}

function Math.clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function Math.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Normalize `value` from [min, max] into [0, 1] (clamped). Returns 0 if min == max.
function Math.normalize01(value: number, min: number, max: number): number
	if max == min then
		return 0
	end
	return Math.clamp((value - min) / (max - min), 0, 1)
end

-- Cost of the `level`-th purchase (0-indexed) under exponential growth, floored.
function Math.exponentialCost(base: number, growth: number, level: number): number
	return math.floor(base * growth ^ level)
end

-- Weighted selection: given non-negative `weights` and a roll in [0, 1], return
-- the chosen 1-based index. Negative weights are treated as 0. Deterministic for
-- a given roll, so callers can drive it from a seeded RNG.
function Math.weightedIndex(weights: { number }, roll01: number): number
	local total = 0
	for _, w in weights do
		total += math.max(0, w)
	end
	if total <= 0 then
		return 1
	end
	local target = Math.clamp(roll01, 0, 1) * total
	local acc = 0
	for i, w in weights do
		acc += math.max(0, w)
		-- Strict `<` so a zero-weight leading entry (whose cumulative
		-- contribution is 0) can never be selected at roll 0.
		if target < acc then
			return i
		end
	end
	return #weights
end

return Math
