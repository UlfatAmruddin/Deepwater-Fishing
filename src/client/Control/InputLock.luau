--!strict
-- Locks the local player into the seated boat experience.
--
-- Removes the default movement/jump controller and sinks movement inputs so
-- the avatar cannot walk, jump, swim, climb, or drive locally. Camera rotation
-- is already impossible because the camera is Scriptable (see FixedCamera).
-- This is the client half; the server independently anchors the character
-- (server/Presentation/PlayerAnchor), so nothing here is trusted for security.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local InputLock = {}

local FREEZE_ACTION = "DeepwaterFreezeMovement"

-- Every key that could produce movement, a jump, or vehicle throttle input.
local MOVEMENT_KEYS = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Space,
	Enum.KeyCode.Q,
	Enum.KeyCode.E,
	Enum.KeyCode.ButtonA, -- gamepad jump
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.Thumbstick1, -- gamepad movement stick
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
}

local function sink(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

-- Disable Roblox's default control module so it stops driving the Humanoid.
local function disablePlayerModuleControls()
	local player = Players.LocalPlayer
	local scripts = player:FindFirstChild("PlayerScripts")
	local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return
	end

	local ok, controls = pcall(function()
		return require(playerModule :: ModuleScript):GetControls()
	end)
	if ok and controls then
		controls:Disable()
	end
end

function InputLock.start()
	disablePlayerModuleControls()

	-- Belt-and-suspenders: even if the control module re-enables, these binds
	-- sink the keys at high priority so they do nothing.
	ContextActionService:BindActionAtPriority(
		FREEZE_ACTION,
		sink,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(MOVEMENT_KEYS)
	)
end

function InputLock.stop()
	ContextActionService:UnbindAction(FREEZE_ACTION)
end

return InputLock
