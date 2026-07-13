-- Headless unit tests for the pure PayloadGuard. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local PayloadGuard = require("../src/server/Net/PayloadGuard")

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

local inf = math.huge
local nan = 0 / 0

-- isFiniteNumber: rejects non-numbers, NaN, and +/- infinity.
check("finite: integer", PayloadGuard.isFiniteNumber(3))
check("finite: negative float", PayloadGuard.isFiniteNumber(-2.5))
check("finite: rejects string", not PayloadGuard.isFiniteNumber("3"))
check("finite: rejects nil", not PayloadGuard.isFiniteNumber(nil))
check("finite: rejects NaN", not PayloadGuard.isFiniteNumber(nan))
check("finite: rejects +inf", not PayloadGuard.isFiniteNumber(inf))
check("finite: rejects -inf", not PayloadGuard.isFiniteNumber(-inf))
check("finite: rejects boolean", not PayloadGuard.isFiniteNumber(true))

-- isTable
check("isTable: empty table", PayloadGuard.isTable({}))
check("isTable: rejects nil", not PayloadGuard.isTable(nil))
check("isTable: rejects number", not PayloadGuard.isTable(5))

-- finiteInRange: clamps finite numbers, rejects non-finite outright.
check("range: within stays", PayloadGuard.finiteInRange(5, 0, 10) == 5)
check("range: clamps below to min", PayloadGuard.finiteInRange(-3, 0, 10) == 0)
check("range: clamps above to max", PayloadGuard.finiteInRange(99, 0, 10) == 10)
check("range: NaN rejected (nil)", PayloadGuard.finiteInRange(nan, 0, 10) == nil)
check("range: inf rejected (nil)", PayloadGuard.finiteInRange(inf, 0, 10) == nil)
check("range: string rejected (nil)", PayloadGuard.finiteInRange("5", 0, 10) == nil)

-- nextSequence: strictly increasing finite numbers only (blocks replay/dupes).
check("seq: accepts increment", PayloadGuard.nextSequence(4, 5) == 5)
check("seq: rejects duplicate", PayloadGuard.nextSequence(5, 5) == nil)
check("seq: rejects stale/replay", PayloadGuard.nextSequence(5, 3) == nil)
check("seq: rejects NaN", PayloadGuard.nextSequence(5, nan) == nil)
check("seq: rejects inf", PayloadGuard.nextSequence(5, inf) == nil)
check("seq: rejects non-number", PayloadGuard.nextSequence(5, "6") == nil)

-- gate: order is rate -> payload -> profile; returns (allowed, reason?).
local function gate(rateOk, payloadOk, profileReady, requireProfile)
	return PayloadGuard.gate({
		rateOk = rateOk,
		payloadOk = payloadOk,
		profileReady = profileReady,
		requireProfile = requireProfile,
	})
end

do
	local ok, reason = gate(true, true, true, true)
	check("gate: all-ok allows", ok and reason == nil)
end
do
	local ok, reason = gate(false, true, true, true)
	check("gate: rate first", not ok and reason == "rate_limited")
end
do
	-- Rate limit takes precedence over a bad payload.
	local ok, reason = gate(false, false, false, true)
	check("gate: rate precedes payload", not ok and reason == "rate_limited")
end
do
	local ok, reason = gate(true, false, true, true)
	check("gate: bad payload", not ok and reason == "bad_request")
end
do
	local ok, reason = gate(true, true, false, true)
	check("gate: profile not ready when required", not ok and reason == "profile_not_ready")
end
do
	local ok, reason = gate(true, true, false, false)
	check("gate: profile not required is allowed", ok and reason == nil)
end

-- reject: the canonical RemoteFunction failure shape.
do
	local r = PayloadGuard.reject("not_implemented")
	check("reject: ok=false", r.ok == false)
	check("reject: carries reason", r.reason == "not_implemented")
end

return { passed = passed, failed = failed }
