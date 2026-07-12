--!strict
-- Server entry point for Deepwater Fishing.
--
-- Stage 0 responsibilities only:
--   * boot the per-player lifecycle (which anchors/locks each player to the
--     boat and opens/closes their data session hook).
-- No fishing or economy logic yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local PlayerLifecycle = require(script.PlayerLifecycle)

Log.info("Server booting...")
PlayerLifecycle.start()
Log.info("Server ready.")
