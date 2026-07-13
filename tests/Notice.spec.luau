-- Headless unit tests for the pure Notice builder. Run via Lune (see run.luau).
-- Returns { passed, failed } so the runner can aggregate and set an exit code.

local Notice = require("../src/server/Net/Notice")

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

-- Known codes carry the code through and map to a specific, non-empty message.
for _, code in
	{ "rate_limited", "bad_request", "profile_not_ready", "not_implemented", "internal_error" }
do
	local n = Notice.build(code)
	check("build(" .. code .. ") echoes code", n.code == code)
	check("build(" .. code .. ") has a message", type(n.message) == "string" and #n.message > 0)
end

-- Distinct known codes produce distinct messages (no accidental collisions).
check(
	"rate_limited != bad_request message",
	Notice.build("rate_limited").message ~= Notice.build("bad_request").message
)
check(
	"profile_not_ready != not_implemented message",
	Notice.build("profile_not_ready").message ~= Notice.build("not_implemented").message
)

-- Unknown code -> generic message, but the code is still echoed for client branching.
do
	local n = Notice.build("some_internal_secret_code")
	check("unknown code echoed back", n.code == "some_internal_secret_code")
	check("unknown code -> generic message", n.message == "That action couldn't be completed.")
end

-- The message must never leak internal detail: unknown codes never surface
-- anything but the fixed generic string.
do
	local n = Notice.build("stacktrace: SessionCore:88 nil profile")
	check(
		"unknown internal-looking code still generic",
		n.message == "That action couldn't be completed."
	)
end

return { passed = passed, failed = failed }
