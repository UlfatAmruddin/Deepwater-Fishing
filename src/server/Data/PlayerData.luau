--!strict
-- Player data layer.
--
-- Owns the ProfileStore-backed persistence for the whole server: loads exactly
-- one profile per player session (SessionCore prevents duplicates), reconciles +
-- migrates on load, saves on release and BindToClose, and exposes ONLY
-- controlled server-side read/mutation methods. The ProfileStore object and the
-- live mutable profile table are never handed out — and never reach a client
-- (this module exposes no RemoteEvent/RemoteFunction).
--
-- This module + the vendored ProfileStore + ProfileStoreAdapter are the only
-- code permitted to touch DataStoreService (see the CI quarantine).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local ProfileSchema = require(script.Parent.ProfileSchema)
local SessionCore = require(script.Parent.SessionCore)
local ProfileStoreAdapter = require(script.Parent.ProfileStoreAdapter)

type ProfileData = ProfileSchema.ProfileData

local PlayerData = {}

local STORE_NAME = "PlayerData"
local LOAD_ATTEMPTS = 5
local LOAD_BACKOFF = 2 -- seconds base; retries wait 2, 4, 6, 8 (bounded, linear)

local core: SessionCore.SessionCore? = nil
local started = false

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function deepCopy(source: { [any]: any }): { [any]: any }
	local copy = {}
	for key, value in source do
		copy[key] = if type(value) == "table" then deepCopy(value) else value
	end
	return copy
end

-- Start the data layer once, from the server bootstrap. Sets up the store, the
-- session core, and the shutdown hook.
function PlayerData.start()
	if started then
		return
	end
	started = true

	local storeName = ("%s_%s"):format(GameConfig.dataStoreScope, STORE_NAME)
	local adapter = ProfileStoreAdapter.new(storeName, ProfileSchema.getDefaults())
	core = SessionCore.new({
		adapter = (adapter :: any) :: SessionCore.Adapter,
		schema = { reconcile = ProfileSchema.reconcile, migrate = ProfileSchema.migrate },
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		config = { maxAttempts = LOAD_ATTEMPTS, backoff = LOAD_BACKOFF },
	})

	game:BindToClose(function()
		local c = core
		if not c then
			return
		end
		for _, player in Players:GetPlayers() do
			local session = c:get(keyFor(player))
			if session then
				session.data.lastLogoutAt = os.time()
			end
		end
		c:releaseAll()
	end)

	Log.info("PlayerData started:", storeName, if RunService:IsStudio() then "(mock)" else "(live)")
end

-- Join hook. Loads the profile on its own thread so the caller never yields; the
-- load itself retries transient failures with bounded backoff inside SessionCore.
function PlayerData.onPlayerAdded(player: Player)
	local c = core
	if not c then
		return
	end
	local key = keyFor(player)

	task.spawn(function()
		local ok, session, reason = c:load(key)
		if not ok then
			if reason == "released" then
				-- Player left while loading; SessionCore already released the session.
				return
			elseif reason == "duplicate" then
				-- A previous session for this player is still closing. Kick so Roblox
				-- re-routes a clean load rather than stranding them with no data.
				Log.warn("Profile still closing for", player.Name, "- kicking to reload.")
				player:Kick("Your previous session is still closing. Please rejoin.")
			else
				Log.warn("Could not load profile for", player.Name, "- kicking to protect data.")
				player:Kick("Your data could not be loaded. Please rejoin.")
			end
			return
		end
		assert(session, "load succeeded without a session")

		-- Player left mid-load: release immediately so the lock does not linger.
		if player.Parent == nil then
			c:release(key)
			return
		end

		-- ProfileStore fires OnSessionEnd on EVERY end. Only a genuine external
		-- steal (another server took the lock) leaves the session still tracked
		-- here — our own release()/shutdown clears it before EndSession fires — so
		-- gate the kick on the session still being loaded.
		session:onSessionEnd(function()
			if not c:isLoaded(key) then
				return -- self-initiated release or shutdown; nothing to do.
			end
			c:forget(key)
			player:Kick("Your data session was claimed by another server. Please rejoin.")
		end)

		Log.info("Profile loaded for", player.Name)
	end)
end

-- Leave hook. Stamps logout time on the safe save path, then releases.
function PlayerData.onPlayerRemoving(player: Player)
	local c = core
	if not c then
		return
	end
	local key = keyFor(player)
	local session = c:get(key)
	if session then
		session.data.lastLogoutAt = os.time()
	end
	c:release(key)
end

-- Whether the player's profile is loaded and ready.
function PlayerData.isReady(player: Player): boolean
	local c = core
	if not c then
		return false
	end
	return c:isLoaded(keyFor(player))
end

-- Deep, READ-ONLY snapshot of a player's profile (a copy — the live mutable
-- table is never exposed). Returns nil if the profile is not loaded.
function PlayerData.getSnapshot(player: Player): ProfileData?
	local c = core
	local session = if c then c:get(keyFor(player)) else nil
	if not session then
		return nil
	end
	return (deepCopy(session.data) :: any) :: ProfileData
end

-- The ONLY sanctioned write path: runs `mutator` against the live profile data
-- server-side. Returns false if the profile is not loaded.
function PlayerData.update(player: Player, mutator: (ProfileData) -> ()): boolean
	local c = core
	local session = if c then c:get(keyFor(player)) else nil
	if not session then
		return false
	end
	mutator((session.data :: any) :: ProfileData)
	return true
end

return PlayerData
