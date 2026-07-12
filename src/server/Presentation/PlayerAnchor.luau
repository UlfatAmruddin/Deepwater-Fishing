--!strict
-- Server-authoritative lock keeping each player seated on the boat anchor.
--
-- The player cannot walk, jump, swim, climb, fly, or leave the anchor.
-- Enforcing this on the server means a hacked client cannot override it; the
-- client half (client/Control/InputLock) only removes default controls and
-- sinks input for a clean local feel.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)
local Cleanup = require(Shared.Util.Cleanup)
local Log = require(Shared.Util.Log)

local PlayerAnchor = {}

local DISABLED_STATES = {
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
}

local function findBoatAnchor(): BasePart?
	local scene = Workspace:FindFirstChild(SceneConfig.sceneName)
	if not scene then
		return nil
	end
	local anchor = scene:FindFirstChild(SceneConfig.boatAnchorName, true)
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end
	return nil
end

function PlayerAnchor.lock(player: Player, character: Model, trove: Cleanup.Cleanup)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		Log.warn("Could not resolve Humanoid/HumanoidRootPart for", player.Name)
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end

	local anchorPart = findBoatAnchor()
	if anchorPart then
		root.CFrame = anchorPart.CFrame + Vector3.new(0, 2, 0)
	else
		Log.warn(
			("Boat anchor '%s' not found under '%s' - run scene/BuildScene.luau in Studio."):format(
				SceneConfig.boatAnchorName,
				SceneConfig.sceneName
			)
		)
	end

	-- Anchoring the root part is the hard guarantee the player never moves.
	root.Anchored = true

	-- If anything tries to re-grant movement, clamp it straight back to zero.
	trove:add(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed ~= 0 then
			humanoid.WalkSpeed = 0
		end
	end))

	Log.info("Anchored player to boat:", player.Name)
end

return PlayerAnchor
