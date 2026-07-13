-- Headless tests for SessionCore with a fake injected persistence adapter.
-- Covers: load + reconcile, duplicate prevention, retry/backoff, malformed data,
-- release, shutdown (releaseAll), and external session end (forget). Run via Lune.

local SessionCore = require("../src/server/Data/SessionCore")
local ProfileSchema = require("../src/server/Data/ProfileSchema")
local FakeAdapter = require("./support/FakeAdapter")

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

local schema = { reconcile = ProfileSchema.reconcile, migrate = ProfileSchema.migrate }

local function noopWait() end

local function makeCore(adapter, maxAttempts)
	return SessionCore.new({
		adapter = adapter,
		schema = schema,
		wait = noopWait,
		config = { maxAttempts = maxAttempts or 5, backoff = 1 },
	})
end

-- Load one profile; it is migrated + reconciled.
do
	local adapter = FakeAdapter.new({
		dataFor = function()
			return { coins = 100 }
		end,
	})
	local core = makeCore(adapter)
	local ok, session = core:load("k1")
	check("load succeeds", ok == true and session ~= nil)
	check(
		"loaded profile is reconciled to current version",
		session.data.schemaVersion == ProfileSchema.CURRENT_VERSION
	)
	check("load preserves saved coins", session.data.coins == 100)
	check("load fills defaults", session.data.activeZone == "sunny_shallows")
	check("activeCount is 1", core:activeCount() == 1)
	check("isLoaded is true", core:isLoaded("k1") == true)
end

-- Duplicate session prevention.
do
	local core = makeCore(FakeAdapter.new({}))
	local ok1 = core:load("k1")
	local ok2, _, reason = core:load("k1")
	check("first load ok", ok1 == true)
	check("duplicate load is rejected", ok2 == false and reason == "duplicate")
	check("still exactly one session", core:activeCount() == 1)
end

-- Retry transient failures with bounded (linear) backoff.
do
	local waits = {}
	local adapter = FakeAdapter.new({ failTimes = 2 })
	local core = SessionCore.new({
		adapter = adapter,
		schema = schema,
		wait = function(seconds)
			table.insert(waits, seconds)
		end,
		config = { maxAttempts = 5, backoff = 2 },
	})
	local ok = core:load("k1")
	check("load succeeds after retrying", ok == true)
	check("adapter was tried 3 times", adapter.startAttempts == 3)
	check(
		"waited twice with linear backoff (2, 4)",
		#waits == 2 and waits[1] == 2 and waits[2] == 4
	)
end

-- Give up after maxAttempts; the key stays loadable (not stuck "loading").
do
	local adapter = FakeAdapter.new({ failTimes = 10 })
	local core = makeCore(adapter, 3)
	local ok, _, reason = core:load("k1")
	check("load fails after max attempts", ok == false and reason == "failed")
	check("adapter tried exactly maxAttempts", adapter.startAttempts == 3)
	check("no session recorded", core:activeCount() == 0)
	check("failed load is retryable", core:isLoaded("k1") == false)
end

-- Malformed/corrupt saved data is made safe on load.
do
	local adapter = FakeAdapter.new({
		dataFor = function()
			return { coins = "bad", schemaVersion = 0, upgrades = "broken" }
		end,
	})
	local core = makeCore(adapter)
	local ok, session = core:load("k1")
	check("corrupt data still loads", ok == true)
	check("corrupt coins reset to default", session.data.coins == 0)
	check(
		"corrupt upgrades reset to a table",
		type(session.data.upgrades) == "table" and session.data.upgrades.LineLength == 0
	)
	check("schemaVersion migrated up", session.data.schemaVersion == ProfileSchema.CURRENT_VERSION)
end

-- Release ends the session, drops it, and allows a reload.
do
	local adapter = FakeAdapter.new({})
	local core = makeCore(adapter)
	core:load("k1")
	core:release("k1")
	check("release ended the session", adapter.ended["k1"] == true)
	check("release dropped the session", core:isLoaded("k1") == false)
	check("can reload after release", (core:load("k1")) == true)
end

-- Release is idempotent and safe when nothing is loaded.
do
	local core = makeCore(FakeAdapter.new({}))
	core:release("never-loaded")
	check("release of an unloaded key is a no-op", core:activeCount() == 0)
end

-- Shutdown releases every active session.
do
	local adapter = FakeAdapter.new({})
	local core = makeCore(adapter)
	core:load("a")
	core:load("b")
	core:load("c")
	check("three sessions active", core:activeCount() == 3)
	core:releaseAll()
	check("shutdown released all sessions", core:activeCount() == 0)
	check("every session was ended", adapter.ended.a and adapter.ended.b and adapter.ended.c)
end

-- Forget drops a session WITHOUT ending it (external steal).
do
	local adapter = FakeAdapter.new({})
	local core = makeCore(adapter)
	core:load("k1")
	core:forget("k1")
	check("forget dropped the session", core:isLoaded("k1") == false)
	check("forget did not call endSession", adapter.ended["k1"] ~= true)
end

-- A throwing adapter is treated as a failed attempt and never wedges the key.
do
	local adapter = FakeAdapter.new({ throwTimes = 10 })
	local core = makeCore(adapter, 3)
	local ok, _, reason = core:load("k1")
	check("throwing adapter yields a failed load", ok == false and reason == "failed")
	check("throwing adapter still tried maxAttempts", adapter.startAttempts == 3)
	check("key is not wedged after a throw", core:isLoaded("k1") == false)
	local _, _, reason2 = core:load("k1")
	check("throw does not leave the key stuck loading", reason2 == "failed")
end

-- Retry treats a throw like a nil failure and can still succeed.
do
	local adapter = FakeAdapter.new({ throwTimes = 2 })
	local core = makeCore(adapter, 5)
	check("load succeeds after transient throws", (core:load("k1")) == true)
	check("adapter tried 3 times through throws", adapter.startAttempts == 3)
end

-- A throwing schema releases the acquired session so no lock is orphaned.
do
	local adapter = FakeAdapter.new({})
	local throwingSchema = {
		migrate = function()
			error("bad migration")
		end,
		reconcile = ProfileSchema.reconcile,
	}
	local core = SessionCore.new({
		adapter = adapter,
		schema = throwingSchema,
		wait = noopWait,
		config = { maxAttempts = 2, backoff = 0 },
	})
	local ok, _, reason = core:load("k1")
	check("schema failure fails the load", ok == false and reason == "failed")
	check("schema failure releases the acquired session", adapter.ended["k1"] == true)
	check("schema failure keeps no session", core:isLoaded("k1") == false)
end

-- endSession fires onSessionEnd (models real ProfileStore); release triggers it.
do
	local adapter = FakeAdapter.new({})
	local core = makeCore(adapter)
	local _, session = core:load("k1")
	local fired = false
	session:onSessionEnd(function()
		fired = true
	end)
	core:release("k1")
	check("release fires the session's onSessionEnd", fired == true)
end

-- In-flight guard + deferred release: a second load while one is loading is a
-- duplicate, and a release requested mid-load ends the session on completion.
do
	local ended = {}
	local gateAdapter = {
		startSession = function(_, key)
			coroutine.yield() -- suspend mid-load
			return {
				data = {},
				isActive = function()
					return true
				end,
				endSession = function()
					ended[key] = true
				end,
				onSessionEnd = function() end,
			}
		end,
	}
	local core = SessionCore.new({
		adapter = gateAdapter,
		schema = schema,
		wait = noopWait,
		config = { maxAttempts = 1, backoff = 0 },
	})
	local result = {}
	local co = coroutine.create(function()
		local ok, _, reason = core:load("k1")
		result.ok = ok
		result.reason = reason
	end)
	coroutine.resume(co) -- runs load to the yield inside startSession

	local dupOk, _, dupReason = core:load("k1")
	check("second load while in flight is a duplicate", dupOk == false and dupReason == "duplicate")

	core:release("k1") -- deferred while loading
	coroutine.resume(co) -- resume; load completes
	check("in-flight load resolves as released", result.ok == false and result.reason == "released")
	check("deferred release ended the session", ended.k1 == true)
	check("no session is kept after a deferred release", core:isLoaded("k1") == false)
end

return { passed = passed, failed = failed }
