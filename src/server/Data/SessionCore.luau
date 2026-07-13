--!strict
-- Headless-testable session-management core for the player data layer.
--
-- No requires and no Roblox globals: the persistence adapter, schema, and wait
-- function are all INJECTED. Tests drive it with a fake in-memory adapter and a
-- no-op wait to exercise load, duplicate prevention, retry/backoff, reconcile,
-- migration, release, and shutdown. PlayerData wires the real ProfileStore-backed
-- adapter and task.wait. This module never touches DataStoreService.

local SessionCore = {}
SessionCore.__index = SessionCore

export type Session = {
	data: { [string]: any }, -- the mutable profile data (Profile.Data)
	isActive: (Session) -> boolean,
	endSession: (Session) -> (),
	onSessionEnd: (Session, () -> ()) -> (),
}

export type Adapter = {
	-- One attempt to acquire a session for `key`; returns the session or nil on
	-- failure (yields in the real adapter, synchronous in the fake). May throw —
	-- SessionCore treats a throw as a failed attempt.
	startSession: (Adapter, key: string) -> Session?,
}

export type Schema = {
	reconcile: ({ [string]: any }) -> { [string]: any },
	migrate: ({ [string]: any }) -> { [string]: any },
}

export type Config = {
	maxAttempts: number,
	backoff: number, -- seconds; each retry waits backoff * attempt (bounded, linear)
}

type Deps = {
	adapter: Adapter,
	schema: Schema,
	wait: (number) -> (),
	config: Config,
}

export type SessionCore = typeof(setmetatable(
	{} :: {
		_adapter: Adapter,
		_schema: Schema,
		_wait: (number) -> (),
		_maxAttempts: number,
		_backoff: number,
		_sessions: { [string]: Session },
		_loading: { [string]: boolean },
		_pendingRelease: { [string]: boolean },
	},
	SessionCore
))

function SessionCore.new(deps: Deps): SessionCore
	return setmetatable({
		_adapter = deps.adapter,
		_schema = deps.schema,
		_wait = deps.wait,
		_maxAttempts = math.max(1, deps.config.maxAttempts),
		_backoff = math.max(0, deps.config.backoff),
		_sessions = {},
		_loading = {},
		_pendingRelease = {},
	}, SessionCore)
end

-- Load exactly one session per key. Returns:
--   (true, session)          on success (data migrated then reconciled),
--   (false, nil, "duplicate")  if a session is already loaded/loading,
--   (false, nil, "released")   if release() was requested while this load ran
--                              (the just-acquired session is ended, not kept),
--   (false, nil, "failed")     if the adapter never returned a session within
--                              maxAttempts, or migration/reconcile threw.
-- The _loading lock is always cleared on every exit — a throwing adapter or
-- schema can never permanently wedge the key.
function SessionCore.load(self: SessionCore, key: string): (boolean, Session?, string?)
	if self._sessions[key] or self._loading[key] then
		return false, nil, "duplicate"
	end
	self._loading[key] = true

	local session: Session? = nil
	for attempt = 1, self._maxAttempts do
		local ok, result = pcall(self._adapter.startSession, self._adapter, key)
		if ok and result then
			session = result
			break
		end
		if attempt < self._maxAttempts then
			self._wait(self._backoff * attempt)
		end
	end

	if not session then
		self._loading[key] = nil
		return false, nil, "failed"
	end

	-- Migrate + reconcile before publishing. If the schema throws, release the
	-- just-acquired session so its lock is never orphaned.
	local schemaOk = pcall(function()
		self._schema.migrate(session.data)
		self._schema.reconcile(session.data)
	end)
	if not schemaOk then
		self._loading[key] = nil
		self._pendingRelease[key] = nil
		pcall(function()
			session:endSession()
		end)
		return false, nil, "failed"
	end

	-- release() was requested while this load was in flight: end it, don't keep.
	if self._pendingRelease[key] then
		self._pendingRelease[key] = nil
		self._loading[key] = nil
		pcall(function()
			session:endSession()
		end)
		return false, nil, "released"
	end

	self._loading[key] = nil
	self._sessions[key] = session
	return true, session
end

function SessionCore.get(self: SessionCore, key: string): Session?
	return self._sessions[key]
end

function SessionCore.isLoaded(self: SessionCore, key: string): boolean
	return self._sessions[key] ~= nil
end

function SessionCore.activeCount(self: SessionCore): number
	local count = 0
	for _ in self._sessions do
		count += 1
	end
	return count
end

-- Release a session: end it (save + release the lock) and drop it. Idempotent; a
-- failing endSession is swallowed so cleanup always completes. If a load for the
-- key is still in flight, the release is deferred to the load's completion so the
-- lock is not orphaned.
function SessionCore.release(self: SessionCore, key: string)
	if self._loading[key] then
		self._pendingRelease[key] = true
		return
	end
	local session = self._sessions[key]
	if not session then
		return
	end
	self._sessions[key] = nil
	pcall(function()
		session:endSession()
	end)
end

-- Drop a session that has ALREADY ended externally (e.g. ProfileStore handed the
-- lock to another server) — no endSession call. Idempotent.
function SessionCore.forget(self: SessionCore, key: string)
	self._sessions[key] = nil
	self._loading[key] = nil
	self._pendingRelease[key] = nil
end

-- Release every active session — used on BindToClose. Safe to nil keys mid-loop.
function SessionCore.releaseAll(self: SessionCore)
	for key in self._sessions do
		self:release(key)
	end
end

return SessionCore
