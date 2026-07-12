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

return { passed = passed, failed = failed }
