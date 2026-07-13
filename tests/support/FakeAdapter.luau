-- In-memory persistence adapter for headless SessionCore tests. Models the real
-- ProfileStoreAdapter contract: synchronous, can fail or THROW the first N
-- startSession attempts (transient failures), hands back arbitrary (e.g. corrupt
-- / old-version) session data, and — like the real ProfileStore — fires the
-- registered onSessionEnd callbacks when a session ends.
--
-- Config:
--   throwTimes : number  -- first N startSession calls raise an error
--   failTimes  : number  -- next N startSession calls return nil, then succeed
--   dataFor    : (key) -> table  -- initial Profile.Data for a session (default {})
--
-- Inspectable fields: `startAttempts` (count), `ended` (key -> true).

local FakeAdapter = {}
FakeAdapter.__index = FakeAdapter

function FakeAdapter.new(config)
	config = config or {}
	return setmetatable({
		_throwTimes = config.throwTimes or 0,
		_failTimes = config.failTimes or 0,
		_dataFor = config.dataFor or function()
			return {}
		end,
		startAttempts = 0,
		ended = {},
	}, FakeAdapter)
end

function FakeAdapter.startSession(self, key)
	self.startAttempts += 1
	if self.startAttempts <= self._throwTimes then
		error("simulated adapter error")
	end
	if self.startAttempts <= self._throwTimes + self._failTimes then
		return nil -- simulate a transient (non-throwing) DataStore failure
	end

	local adapter = self
	local isEnded = false
	local endCallbacks = {}

	local function fireEnd()
		isEnded = true
		adapter.ended[key] = true
		for _, callback in endCallbacks do
			callback()
		end
	end

	local session = {
		data = adapter._dataFor(key),
		isActive = function()
			return not isEnded
		end,
		endSession = fireEnd, -- real ProfileStore fires OnSessionEnd on EndSession
		onSessionEnd = function(_, callback)
			table.insert(endCallbacks, callback)
		end,
		-- Test-only: simulate ProfileStore ending the session externally.
		triggerExternalEnd = fireEnd,
	}
	return session
end

return FakeAdapter
