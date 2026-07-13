-- Headless test runner for Deepwater Fishing.
--
-- Runs pure (no Roblox dependency) spec modules under Lune:
--   lune run tests/run
--
-- Roblox-coupled modules are exercised in-engine, not here. This runner only
-- covers logic that can be verified without a DataModel.

local process = require("@lune/process")

local SPECS = {
	"Math",
	"Rng",
	"PlaneSpace",
	"Content",
	"ProfileSchema",
	"SessionCore",
}

local totalPassed = 0
local totalFailed = 0

for _, name in SPECS do
	local result = require("./" .. name .. ".spec")
	totalPassed += result.passed
	totalFailed += result.failed
	print(("%s: %d passed, %d failed"):format(name, result.passed, result.failed))
end

print(("TOTAL: %d passed, %d failed"):format(totalPassed, totalFailed))

if totalFailed > 0 then
	process.exit(1)
end
