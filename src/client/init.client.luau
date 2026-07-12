--!strict
-- Client entry point for Deepwater Fishing.
--
-- Stage 0: install the fixed 2.5D camera and lock all player controls so the
-- avatar stays seated on the boat. No fishing/economy UI yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local FixedCamera = require(script.Camera.FixedCamera)
local InputLock = require(script.Control.InputLock)

Log.info("Client booting...")
InputLock.start()
FixedCamera.start()
Log.info("Client ready.")
