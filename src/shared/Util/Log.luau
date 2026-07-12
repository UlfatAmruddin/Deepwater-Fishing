--!strict
-- Tiny tagged logger so server/client output is easy to filter.

local Log = {}

local PREFIX = "[Deepwater]"

function Log.info(...: any)
	print(PREFIX, ...)
end

function Log.warn(...: any)
	warn(PREFIX, ...)
end

return Log
