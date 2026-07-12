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
local Math = require(Shared.Util.Math)

local FixedCamera = {}

local RENDER_STEP_NAME = "DeepwaterFixedCamera"

-- The authored camera CFrame: prefer the scene's CameraAnchor, else fall back
-- to the configured position/lookAt. Read once at start; it never changes.
local function resolveHomeCFrame(): CFrame
	local scene = Workspace:FindFirstChild(SceneConfig.sceneName)
	local anchor = scene and scene:FindFirstChild("CameraAnchor", true)
	if anchor and anchor:IsA("BasePart") then
		return anchor.CFrame
	end
	return CFrame.lookAt(SceneConfig.camera.position, SceneConfig.camera.lookAt)
end

function FixedCamera.start()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = SceneConfig.camera.fieldOfView

	local home = resolveHomeCFrame()
	local homeRotation = home - home.Position -- rotation-only CFrame
	local panX = SceneConfig.camera.panX
	local panY = SceneConfig.camera.panY
	local lerp = SceneConfig.camera.panLerp

	local current = home

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, function()
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
