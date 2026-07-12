--!strict
-- Locks the local player into the seated boat experience.
--
-- Disables the default movement/jump controller and sinks movement inputs so the
-- avatar cannot walk, jump, swim, climb, or drive locally. Camera rotation is
-- already impossible because the camera is Scriptable (see FixedCamera). This is
-- the client half only; the server independently seats/anchors the character
-- (server/Presentation/PlayerAnchor), so nothing here is trusted for security —
-- it keeps the local feel clean (no dead input, no visible touch thumbstick
-- driving a locked avatar).

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

local connections: { RBXScriptConnection } = {}

local function sink(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

-- Disable Roblox's default control module. This covers keyboard, gamepad,
-- click-to-move, AND the mobile touch thumbstick — everything the CAS key-sink
-- below cannot reach. Must be re-run on each spawn because the PlayerModule
-- rebuilds and re-enables its controls for every new character.
local function disablePlayerModuleControls()
	local player = Players.LocalPlayer
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = scripts and scripts:WaitForChild("PlayerModule", 10)
	if not playerModule or not playerModule:IsA("ModuleScript") then
		return
	end

	-- luau-lsp cannot statically resolve a require of the runtime-provided
	-- PlayerModule, so alias `require` to skip its path analysis. Guarded by pcall
	-- in case the module shape changes across Roblox updates.
	local requireModule = require :: (ModuleScript) -> any
	local ok, controls = pcall(function()
		return requireModule(playerModule):GetControls()
	end)
	if ok and controls then
		controls:Disable()
	end
end

function InputLock.start()
	disablePlayerModuleControls()

	-- Re-disable on each respawn (the PlayerModule re-enables its controls).
	local player = Players.LocalPlayer
	table.insert(connections, player.CharacterAdded:Connect(disablePlayerModuleControls))

	-- Belt-and-suspenders: sink movement/jump keys at high priority so keyboard
	-- and gamepad do nothing even if the control module comes back.
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
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
end

return InputLock
