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

return Math
