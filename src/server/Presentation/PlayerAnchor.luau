--!strict
-- Server-authoritative lock keeping each player seated on the boat anchor.
--
-- The player cannot walk, jump, swim, climb, fly, or leave the anchor.
-- Enforcing this on the server means a hacked client cannot override it; the
-- client half (client/Control/InputLock) only removes default controls and
-- sinks input for a clean local feel.
--
-- Presentation contract: if the authored anchor is a Seat (the placeholder scene
-- builds one, and a developer's replacement boat is expected to keep a Seat
-- named SceneConfig.boatAnchorName), the humanoid is genuinely put into the
-- Seated state so it plays the sitting pose the 2.5D contract calls for. Any
-- other BasePart (or a missing anchor) falls back to hard-anchoring the
-- HumanoidRootPart. Note a VehicleSeat is intentionally NOT treated as a seat —
-- it would grant throttle/steer input — so it takes the anchored fallback path.
-- Either way the player is fully immobilised on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)
local SceneContract = require(Shared.SceneContract)
local Cleanup = require(Shared.Util.Cleanup)
local Log = require(Shared.Util.Log)

local PlayerAnchor = {}

-- Locomotion states a seated player must never enter. Seated is deliberately NOT
-- disabled — we rely on it for the sitting pose.
local DISABLED_STATES = {
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
}

-- Resolve the boat anchor through the asset-replacement contract (tag-first,
-- name-fallback) so a swapped-in boat model works with no change here. Returns
-- a Seat when one is tagged/named (seated path) or any anchor BasePart.
local function findBoatAnchor(): BasePart?
	return SceneContract.getBoatAnchorPart()
end

function PlayerAnchor.lock(player: Player, character: Model, trove: Cleanup.Cleanup)
	local humanoidInstance = character:WaitForChild("Humanoid", 10)
	local rootInstance = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = if humanoidInstance and humanoidInstance:IsA("Humanoid")
		then humanoidInstance
		else nil
	local root = if rootInstance and rootInstance:IsA("BasePart") then rootInstance else nil
	if not humanoid then
		Log.warn("Could not resolve Humanoid for", player.Name)
		return
	end
	if not root then
		Log.warn("Could not resolve HumanoidRootPart for", player.Name)
		return
	end

	-- Defense-in-depth: zero out every locomotion affordance so a hacked client
	-- has nothing to drive, seated or not.
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end

	local anchorPart = findBoatAnchor()
	local seat: Seat? = if anchorPart and anchorPart:IsA("Seat") then anchorPart else nil

	if seat then
		local activeSeat = seat
		-- Genuinely seat the avatar: the Seat's weld holds it in a sitting pose.
		activeSeat:Sit(humanoid)

		-- Take server network ownership of the character. A seated player still
		-- owns their own HumanoidRootPart by default, and WalkSpeed=0 only blocks
		-- Humanoid-driven locomotion — it does NOT stop a hacked client from
		-- CFrame-driving a client-owned root off the X/Y plane. Server ownership
		-- closes that hole (the anchored-root fallback below is already
		-- server-authoritative, and SetNetworkOwner errors on anchored parts, so
		-- it is only needed on this seated path). Requires the Seat to be Anchored
		-- (SceneValidator warns otherwise).
		pcall(function()
			root:SetNetworkOwner(nil)
		end)

		-- Re-seat if anything (exploit, forced state change) knocks a live player
		-- out. Seated fires with active=false when they leave the seat; ignore the
		-- death case (Health <= 0) so we never try to re-seat a corpse.
		trove:add(humanoid.Seated:Connect(function(active: boolean)
			if not active and activeSeat.Parent ~= nil and humanoid.Health > 0 then
				activeSeat:Sit(humanoid)
			end
		end))

		Log.info("Seated player on boat:", player.Name)
	else
		-- No Seat available (a developer may have swapped in a plain anchor part).
		-- Hard-lock by anchoring the root at/above the anchor point.
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
		Log.info("Anchored player to boat (no Seat found):", player.Name)
	end

	-- If anything tries to re-grant movement, clamp it straight back to zero.
	trove:add(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed ~= 0 then
			humanoid.WalkSpeed = 0
		end
	end))
end

return PlayerAnchor
