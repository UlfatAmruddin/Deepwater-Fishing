--!strict
-- Server entry point for Deepwater Fishing.
--
-- Responsibilities so far:
--   * create the shared Remotes folder eagerly (so clients never wait on it),
--   * start the player data layer (ProfileStore) so profiles load on join,
--   * validate the authored scene and warn on missing/drifted elements,
--   * boot the per-player lifecycle (which seats/anchors each player on the boat
--     and drives the data load/release hooks).
-- No fishing or economy logic yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Data.PlayerData)
local PlayerLifecycle = require(script.PlayerLifecycle)
local SceneValidator = require(script.Scene.SceneValidator)

Log.info("Server booting...")
Remotes.init()
PlayerData.start()
SceneValidator.validate()
PlayerLifecycle.start()
Log.info("Server ready.")
