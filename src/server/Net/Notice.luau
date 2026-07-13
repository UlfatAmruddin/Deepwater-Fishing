--!strict
-- Pure builder for user-facing rejection notices.
--
-- Maps an internal reason CODE to a safe, user-facing message. Unknown codes get
-- a generic message so internal server details never leak to the client. The code
-- itself is a stable, non-sensitive enum the client may branch on. A leaf module
-- (no requires) -> headlessly testable.

local Notice = {}

local MESSAGES: { [string]: string } = {
	rate_limited = "You're doing that too fast — please slow down.",
	bad_request = "That action couldn't be processed.",
	profile_not_ready = "Your data is still loading. Please wait a moment.",
	not_implemented = "That feature isn't available yet.",
	internal_error = "Something went wrong. Please try again.",
}

local GENERIC = "That action couldn't be completed."

export type Notice = { code: string, message: string }

-- Build a client-safe notice for an internal reason code.
function Notice.build(code: string): Notice
	return {
		code = code,
		message = MESSAGES[code] or GENERIC,
	}
end

return Notice
