--!strict
-- Pure outgoing-payload sanitizer used by ServerPush.
--
-- Deep-copies a payload keeping ONLY client-safe plain data (string/number/
-- boolean and nested tables), so no live server-owned mutable table is ever sent
-- by reference. It drops:
--   * forbidden keys (seeds, weights, layouts, raw profiles, world-Z / Vector3-ish)
--   * function / userdata (Vector3, CFrame, Instance) / thread values
-- A leaf module (no requires, no Roblox globals) -> headlessly testable.

local Sanitizer = {}

local FORBIDDEN_KEYS: { [string]: boolean } = {
	seed = true,
	seeds = true,
	weight = true,
	weights = true,
	layout = true,
	rng = true,
	profile = true,
	rawprofile = true,
	data = true,
	z = true,
	worldz = true,
	gameplayplanez = true,
	cframe = true,
	position = true,
}

local function sanitizeValue(value: any): any
	local kind = type(value)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return value
	elseif kind == "table" then
		local out: { [any]: any } = {}
		for key, child in value :: { [any]: any } do
			if type(key) == "string" and FORBIDDEN_KEYS[string.lower(key)] then
				continue
			end
			local sanitized = sanitizeValue(child)
			if sanitized ~= nil then
				out[key] = sanitized
			end
		end
		return out
	end
	-- functions, userdata (Vector3/CFrame/Instance), threads, nil -> dropped.
	return nil
end

-- Return a sanitized deep copy of `payload`. A non-table input yields {}.
function Sanitizer.sanitize(payload: any): { [string]: any }
	local result = sanitizeValue(payload)
	return if type(result) == "table" then result else {}
end

return Sanitizer
