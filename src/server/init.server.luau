--!strict
-- Server entry point / composition root for Deepwater Fishing.
--
-- Boot order is deliberate and RACE-SAFE: the Remotes folder and every declared
-- remote are created, and every client->server handler is registered through
-- RemoteGuard, SYNCHRONOUSLY — before any yielding initialization. An early
-- client call therefore always hits a guarded, wired remote and fails safe
-- (profile-not-ready) rather than an unwired one or a hang.
-- No fishing or economy logic yet — the remote handlers are placeholders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Data.PlayerData)
local RemoteGuard = require(script.Net.RemoteGuard)
local Handlers = require(script.Net.Handlers)
local PlayerLifecycle = require(script.PlayerLifecycle)
local SceneValidator = require(script.Scene.SceneValidator)

Log.info("Server booting...")

-- 1. Networking exists before anything else (no yield).
Remotes.init()
RemoteGuard.start({ isReady = PlayerData.isReady })
Handlers.registerAll()

-- 2. Yielding initialization (ProfileStore session/module setup) comes after the
--    handlers are wired, so early client calls are guarded, not dropped.
PlayerData.start()
SceneValidator.validate()
PlayerLifecycle.start()

Log.info("Server ready.")
