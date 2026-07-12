--!strict
-- Fixed 2.5D camera.
--
-- Contract: one fixed orientation (constant yaw/pitch/roll). The camera never
-- rotates with input and never follows the character freely. Only a small,
-- bounded horizontal/vertical pan offset is permitted, and it translates the
-- camera along its own right/up axes without touching its rotation.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)
local SceneContract = require(Shared.SceneContract)
local Math = require(Shared.Util.Math)

local FixedCamera = {}

local RENDER_STEP_NAME = "DeepwaterFixedCamera"

-- The authored camera pose: the scene's CameraAnchor if present (this is what a
-- developer repositions in Studio), else the configured position/lookAt.
local function resolveAnchorCFrame(): CFrame?
	local anchor = SceneContract.getCameraAnchor()
	if anchor then
		return anchor.CFrame
	end
	return nil
end

local function configCFrame(): CFrame
	return CFrame.lookAt(SceneConfig.camera.position, SceneConfig.camera.lookAt)
end

function FixedCamera.start()
	local panX = SceneConfig.camera.panX
	local panY = SceneConfig.camera.panY
	local lerp = SceneConfig.camera.panLerp
	local fov = SceneConfig.camera.fieldOfView

	-- Home pose: prefer the authored CameraAnchor; until it replicates, use the
	-- config fallback. Locked in on the first successful anchor resolve.
	local anchorCFrame = resolveAnchorCFrame()
	local home = anchorCFrame or configCFrame()
	local homeRotation = home - home.Position -- rotation-only CFrame
	local homeLocked = anchorCFrame ~= nil
	local current = home
	local lastCamera: Camera? = nil

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, function()
		-- Re-read every frame: covers a nil-at-boot frame and any later
		-- replacement of Workspace.CurrentCamera (e.g. on some respawn paths).
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		-- Adopt the authored anchor pose as soon as the scene becomes available.
		if not homeLocked then
			local resolved = resolveAnchorCFrame()
			if resolved then
				home = resolved
				homeRotation = home - home.Position
				current = home
				homeLocked = true
			end
		end

		-- (Re-)initialise a newly-adopted camera.
		if camera ~= lastCamera then
			lastCamera = camera
			camera.FieldOfView = fov
		end
		-- Re-assert Scriptable so nothing can hand control back to the player.
		camera.CameraType = Enum.CameraType.Scriptable

		-- Bounded pan target derived from normalised mouse position.
		local viewport = camera.ViewportSize
		local mouse = UserInputService:GetMouseLocation()
		local nx = if viewport.X > 0 then (mouse.X / viewport.X) * 2 - 1 else 0
		local ny = if viewport.Y > 0 then (mouse.Y / viewport.Y) * 2 - 1 else 0

		local offsetX = Math.clamp(nx * panX.max, panX.min, panX.max)
		local offsetY = Math.clamp(-ny * panY.max, panY.min, panY.max)

		-- Target = home translated in its local right/up axes only.
		local target = home * CFrame.new(offsetX, offsetY, 0)
		current = current:Lerp(target, lerp)

		-- Force orientation back to home every frame: position may pan, but
		-- yaw/pitch/roll can never drift.
		camera.CFrame = CFrame.new(current.Position) * homeRotation
	end)
end

function FixedCamera.stop()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end

return FixedCamera
