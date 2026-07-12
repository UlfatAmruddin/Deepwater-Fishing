-- Headless unit tests for the pure Math helper. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local Math = require("../src/shared/Util/Math")

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

check("clamp below min", Math.clamp(-5, 0, 10) == 0)
check("clamp above max", Math.clamp(50, 0, 10) == 10)
check("clamp within range", Math.clamp(5, 0, 10) == 5)
check("lerp midpoint", Math.lerp(0, 10, 0.5) == 5)
check("lerp start", Math.lerp(2, 8, 0) == 2)
check("lerp end", Math.lerp(2, 8, 1) == 8)

check("normalize01 midpoint", Math.normalize01(5, 0, 10) == 0.5)
check("normalize01 clamps above range", Math.normalize01(20, 0, 10) == 1)
check("normalize01 handles equal bounds", Math.normalize01(5, 3, 3) == 0)

check("exponentialCost at level 0", Math.exponentialCost(25, 1.5, 0) == 25)
check("exponentialCost grows", Math.exponentialCost(100, 2, 2) == 400)
check("exponentialCost floors fractional products", Math.exponentialCost(25, 1.5, 1) == 37)

check("weightedIndex picks first at roll 0", Math.weightedIndex({ 1, 1, 1 }, 0) == 1)
check("weightedIndex picks last at roll 1", Math.weightedIndex({ 1, 1, 1 }, 1) == 3)
check("weightedIndex respects weights", Math.weightedIndex({ 0, 10, 0 }, 0.5) == 2)
check("weightedIndex handles all-zero weights", Math.weightedIndex({ 0, 0 }, 0.5) == 1)
check("weightedIndex skips a zero-weight leading entry", Math.weightedIndex({ 0, 1 }, 0) == 2)

return { passed = passed, failed = failed }
