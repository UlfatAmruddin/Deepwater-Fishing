--!strict
-- Pure request-validation helpers used by RemoteGuard.
--
-- No requires, no Roblox globals -> headlessly testable. RemoteGuard delegates
-- its per-call decision (rate / payload / profile-readiness) here so the trust
-- boundary's logic is unit-tested independently of the Roblox remote wiring.

local PayloadGuard = {}

-- A finite number: not a string, not NaN, not +/- infinity.
function PayloadGuard.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function PayloadGuard.isTable(value: any): boolean
	return type(value) == "table"
end

-- A finite number clamped into [min, max], or nil if it is not a finite number.
function PayloadGuard.finiteInRange(value: any, min: number, max: number): number?
	if not PayloadGuard.isFiniteNumber(value) then
		return nil
	end
	return math.max(min, math.min(max, value))
end

-- Monotonic sequence guard: accept `seq` only if it is a finite number strictly
-- greater than `last` (rejects stale, duplicate, and replayed sequence numbers).
-- Returns the accepted seq, or nil to reject.
function PayloadGuard.nextSequence(last: number, seq: any): number?
	if not PayloadGuard.isFiniteNumber(seq) then
		return nil
	end
	if seq <= last then
		return nil
	end
	return seq
end

export type GateInput = {
	rateOk: boolean,
	payloadOk: boolean,
	profileReady: boolean,
	requireProfile: boolean,
}

-- The pure gate decision every remote runs before its handler. Order matters:
-- rate limit, then payload shape, then profile readiness. Returns (allowed,
-- reason?) where reason is a safe code for a Notice / RemoteFunction response.
function PayloadGuard.gate(input: GateInput): (boolean, string?)
	if not input.rateOk then
		return false, "rate_limited"
	end
	if not input.payloadOk then
		return false, "bad_request"
	end
	if input.requireProfile and not input.profileReady then
		return false, "profile_not_ready"
	end
	return true, nil
end

-- The standard RemoteFunction failure response.
function PayloadGuard.reject(reason: string): { ok: boolean, reason: string }
	return { ok = false, reason = reason }
end

return PayloadGuard
