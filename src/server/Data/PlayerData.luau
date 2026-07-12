--!strict
-- Player data access layer.
--
-- CONTRACT (enforced by convention + code review):
--   * This module is the ONLY place permitted to touch DataStoreService.
--   * Persistence will be backed by ProfileStore (the maintained successor to
--     ProfileService), which provides SESSION LOCKING so a player's data is
--     never edited from two servers at once, plus safe retries and
--     save-on-shutdown. Direct DataStoreService calls may exist only inside
--     this module, behind that abstraction.
--   * ProfileStore is added when the data layer lands (Stage 3) — via Wally
--     (MadStudioRoblox/ProfileStore) or a vendored copy. Wally is intentionally
--     deferred until that dependency is actually needed.
--
-- Stage 0 status: STUB. No DataStoreService calls and no profile schema yet.
-- The hooks below already run from PlayerLifecycle (join, leave, and
-- BindToClose) so the wiring and teardown are correct; they become the
-- ProfileStore session start/end points in Stage 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Log = require(ReplicatedStorage:WaitForChild("Shared").Util.Log)

local PlayerData = {}

-- Called when a player joins. Stage 3: start a ProfileStore session
-- (StartSessionAsync) with session locking and load their profile.
function PlayerData.onPlayerAdded(player: Player)
	-- TODO(stage-3): acquire ProfileStore session for `player`.
	Log.info("[data] (stub) would open profile session for", player.Name)
end

-- Called on leave AND from BindToClose on shutdown. Stage 3: end the
-- ProfileStore session (saves + releases the lock). Must stay idempotent.
function PlayerData.onPlayerRemoving(player: Player)
	-- TODO(stage-3): release ProfileStore session for `player`.
	Log.info("[data] (stub) would close profile session for", player.Name)
end

return PlayerData
