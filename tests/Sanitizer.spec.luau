-- Headless unit tests for the pure Sanitizer. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local Sanitizer = require("../src/server/Net/Sanitizer")

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

-- Plain safe data survives.
do
	local out = Sanitizer.sanitize({ coins = 100, name = "Bob", active = true })
	check("keeps number", out.coins == 100)
	check("keeps string", out.name == "Bob")
	check("keeps boolean", out.active == true)
end

-- Forbidden keys are stripped (case-insensitively).
do
	local out = Sanitizer.sanitize({
		seed = 12345,
		Seeds = { 1, 2, 3 },
		WEIGHT = 0.5,
		weights = { 1, 2 },
		layout = { "a", "b" },
		rng = 999,
		profile = { coins = 1 },
		rawProfile = {},
		data = { secret = true },
		z = 42,
		worldZ = 42,
		gameplayPlaneZ = 42,
		cframe = "x",
		position = "y",
		coins = 100,
	})
	check("strips seed", out.seed == nil)
	check("strips Seeds (case-insensitive)", out.Seeds == nil)
	check("strips WEIGHT (case-insensitive)", out.WEIGHT == nil)
	check("strips weights", out.weights == nil)
	check("strips layout", out.layout == nil)
	check("strips rng", out.rng == nil)
	check("strips profile", out.profile == nil)
	check("strips rawProfile", out.rawProfile == nil)
	check("strips data", out.data == nil)
	check("strips z", out.z == nil)
	check("strips worldZ", out.worldZ == nil)
	check("strips gameplayPlaneZ", out.gameplayPlaneZ == nil)
	check("strips cframe", out.cframe == nil)
	check("strips position", out.position == nil)
	check("keeps safe sibling coins", out.coins == 100)
end

-- Forbidden keys are stripped at any nesting depth.
do
	local out = Sanitizer.sanitize({ fish = { name = "Tuna", weight = 9.9, rarity = "rare" } })
	check("nested table kept", type(out.fish) == "table")
	check("nested safe field kept", out.fish.name == "Tuna")
	check("nested rarity kept", out.fish.rarity == "rare")
	check("nested forbidden weight stripped", out.fish.weight == nil)
end

-- Non-plain values (functions, threads) are dropped.
do
	local out =
		Sanitizer.sanitize({ fn = function() end, co = coroutine.create(function() end), keep = 1 })
	check("drops function value", out.fn == nil)
	check("drops thread value", out.co == nil)
	check("keeps plain sibling", out.keep == 1)
end

-- Deep copy: the result must not alias the input's nested tables.
do
	local input = { nested = { count = 1 } }
	local out = Sanitizer.sanitize(input)
	out.nested.count = 999
	check("nested table is a copy, not a reference", input.nested.count == 1)
end

-- Non-table input yields an empty table.
check(
	"nil input -> {}",
	type(Sanitizer.sanitize(nil)) == "table" and next(Sanitizer.sanitize(nil)) == nil
)
check(
	"number input -> {}",
	type(Sanitizer.sanitize(5)) == "table" and next(Sanitizer.sanitize(5)) == nil
)
check(
	"string input -> {}",
	type(Sanitizer.sanitize("x")) == "table" and next(Sanitizer.sanitize("x")) == nil
)

return { passed = passed, failed = failed }
