-- Headless tests for the deterministic RNG. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local Rng = require("../src/shared/Util/Rng")

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

-- Determinism: the same seed reproduces the same sequence.
do
	local a = Rng.new(1234)
	local b = Rng.new(1234)
	local same = true
	for _ = 1, 20 do
		if a:nextNumber() ~= b:nextNumber() then
			same = false
		end
	end
	check("same seed reproduces the sequence", same)
end

check("different seeds diverge", Rng.new(1):nextNumber() ~= Rng.new(2):nextNumber())

-- nextNumber stays in [0, 1).
do
	local r = Rng.new(99)
	local ok = true
	for _ = 1, 500 do
		local n = r:nextNumber()
		if n < 0 or n >= 1 then
			ok = false
		end
	end
	check("nextNumber stays in [0, 1)", ok)
end

-- nextInteger stays within inclusive bounds and returns integers.
do
	local r = Rng.new(7)
	local ok = true
	for _ = 1, 500 do
		local v = r:nextInteger(1, 6)
		if v < 1 or v > 6 or v ~= math.floor(v) then
			ok = false
		end
	end
	check("nextInteger within [1, 6]", ok)
end

-- Over enough draws it reaches both endpoints (no off-by-one truncation).
do
	local r = Rng.new(2024)
	local sawMin, sawMax = false, false
	for _ = 1, 500 do
		local v = r:nextInteger(1, 6)
		if v == 1 then
			sawMin = true
		elseif v == 6 then
			sawMax = true
		end
	end
	check("nextInteger reaches both endpoints", sawMin and sawMax)
end

return { passed = passed, failed = failed }
