--!strict
-- Server entry point for Deepwater Fishing.
--
-- Stage 0 responsibilities only:
--   * create the shared Remotes folder eagerly (so clients never wait on it),
--   * validate the authored scene and warn on missing/drifted elements,
--   * boot the per-player lifecycle (which seats/anchors each player on the boat
--     and opens/closes their data session hook).
-- No fishing or economy logic yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local PlayerLifecycle = require(script.PlayerLifecycle)
local SceneValidator = require(script.Scene.SceneValidator)

Log.info("Server booting...")
Remotes.init()
SceneValidator.validate()
PlayerLifecycle.start()
Log.info("Server ready.")
