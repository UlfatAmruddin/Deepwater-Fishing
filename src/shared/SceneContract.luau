--!strict
-- The asset-replacement contract resolver.
--
-- Gameplay must never depend on a specific mesh name, child index, exact
-- dimension, or PrimaryPart. Instead it resolves the authored scene through this
-- module, which finds each contract point by its CollectionService TAG first
-- (stable + position-independent) and falls back to the friendly instance NAME.
-- A developer can therefore drop in a completely different boat/prop model and,
-- as long as it carries the right tag(s), gameplay keeps working with no code
-- change. See docs/ASSET_REPLACEMENT.md and shared/Content/AssetManifest.
--
-- Contract points (SceneConfig.tags):
--   scene        Model      DwScene         -> the DeepwaterScene root
--   cameraAnchor BasePart   DwCameraAnchor  -> fixed camera pose (read CFrame)
--   boatAnchor   Seat       DwBoatAnchor    -> where players are seated (>= 1)
--   hookOrigin   Attachment DwHookOrigin    -> where the line/hook pays out
--   boatSpawn    SpawnLoc.  DwBoatSpawn     -> on-boat spawn point(s)
--   planeLayer   Folder     DwPlaneLayer    -> depth bands (Index/Z/YTop/YBottom)

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)

local SceneContract = {}

-- Re-exported so callers reference tags through one source of truth.
SceneContract.Tags = SceneConfig.tags

local function firstTagged(tag: string, className: string, root: Instance?): Instance?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA(className) and (root == nil or inst:IsDescendantOf(root)) then
			return inst
		end
	end
	return nil
end

local function allTagged(tag: string, className: string, root: Instance): { Instance }
	local out: { Instance } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA(className) and inst:IsDescendantOf(root) then
			table.insert(out, inst)
		end
	end
	return out
end

-- The scene root: a Model tagged DwScene in Workspace, else named DeepwaterScene.
function SceneContract.getScene(): Model?
	local tagged = firstTagged(SceneConfig.tags.scene, "Model", Workspace)
	if tagged and tagged:IsA("Model") then
		return tagged
	end
	local named = Workspace:FindFirstChild(SceneConfig.sceneName)
	if named and named:IsA("Model") then
		return named
	end
	return nil
end

function SceneContract.getCameraAnchor(): BasePart?
	local scene = SceneContract.getScene()
	if not scene then
		return nil
	end
	local tagged = firstTagged(SceneConfig.tags.cameraAnchor, "BasePart", scene)
	if tagged and tagged:IsA("BasePart") then
		return tagged
	end
	local named = scene:FindFirstChild(SceneConfig.cameraAnchorName, true)
	if named and named:IsA("BasePart") then
		return named
	end
	return nil
end

-- All seats players may be anchored to (the seat pool). Tag-first, name-fallback.
function SceneContract.getBoatAnchors(): { Seat }
	local scene = SceneContract.getScene()
	if not scene then
		return {}
	end
	local out: { Seat } = {}
	for _, inst in allTagged(SceneConfig.tags.boatAnchor, "Seat", scene) do
		if inst:IsA("Seat") then
			table.insert(out, inst)
		end
	end
	if #out == 0 then
		local named = scene:FindFirstChild(SceneConfig.boatAnchorName, true)
		if named and named:IsA("Seat") then
			table.insert(out, named)
		end
	end
	return out
end

-- The anchor as a BasePart (Seat preferred, plain BasePart fallback) so the
-- server can seat OR hard-anchor. Lets a developer supply a non-Seat anchor.
function SceneContract.getBoatAnchorPart(): BasePart?
	local scene = SceneContract.getScene()
	if not scene then
		return nil
	end
	local seat = firstTagged(SceneConfig.tags.boatAnchor, "Seat", scene)
	if seat and seat:IsA("BasePart") then
		return seat
	end
	local part = firstTagged(SceneConfig.tags.boatAnchor, "BasePart", scene)
	if part and part:IsA("BasePart") then
		return part
	end
	local named = scene:FindFirstChild(SceneConfig.boatAnchorName, true)
	if named and named:IsA("BasePart") then
		return named
	end
	return nil
end

function SceneContract.getHookOrigin(): Attachment?
	local scene = SceneContract.getScene()
	if not scene then
		return nil
	end
	local tagged = firstTagged(SceneConfig.tags.hookOrigin, "Attachment", scene)
	if tagged and tagged:IsA("Attachment") then
		return tagged
	end
	local named = scene:FindFirstChild(SceneConfig.hookOriginName, true)
	if named and named:IsA("Attachment") then
		return named
	end
	return nil
end

function SceneContract.getBoatSpawns(): { SpawnLocation }
	local scene = SceneContract.getScene()
	if not scene then
		return {}
	end
	local out: { SpawnLocation } = {}
	for _, inst in allTagged(SceneConfig.tags.boatSpawn, "SpawnLocation", scene) do
		if inst:IsA("SpawnLocation") then
			table.insert(out, inst)
		end
	end
	if #out == 0 then
		local folder = scene:FindFirstChild(SceneConfig.boatSpawnsFolderName, true)
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("SpawnLocation") then
					table.insert(out, child)
				end
			end
		end
	end
	return out
end

-- The depth-band folders, tag-first. Matched to SceneConfig.layers by their
-- Index attribute (see audit), so renaming or re-nesting a band never breaks
-- resolution. Name fallback: the children of the PlaneLayers container.
function SceneContract.getPlaneLayers(): { Instance }
	local scene = SceneContract.getScene()
	if not scene then
		return {}
	end
	local out = allTagged(SceneConfig.tags.planeLayer, "Folder", scene)
	if #out == 0 then
		local container = scene:FindFirstChild(SceneConfig.planeLayersFolderName, true)
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Folder") then
					table.insert(out, child)
				end
			end
		end
	end
	return out
end

-- Single source of contract validation: returns a list of human-readable issues
-- (empty = fully satisfied). SceneValidator logs these; never throws.
function SceneContract.audit(): { string }
	local issues: { string } = {}

	local scene = SceneContract.getScene()
	if not scene then
		table.insert(
			issues,
			("Scene not found (tag '%s' or name '%s'). Run scene/BuildScene.luau in the Studio command bar."):format(
				SceneConfig.tags.scene,
				SceneConfig.sceneName
			)
		)
		return issues
	end

	if scene:GetAttribute("ContractVersion") == nil then
		table.insert(
			issues,
			"Scene root has no ContractVersion attribute — stamp it (see docs/ASSET_REPLACEMENT.md)."
		)
	end

	-- Singleton contract points must be unique so resolution is deterministic.
	if #allTagged(SceneConfig.tags.cameraAnchor, "BasePart", scene) > 1 then
		table.insert(
			issues,
			("Multiple '%s'-tagged parts; camera-anchor resolution is ambiguous — keep one."):format(
				SceneConfig.tags.cameraAnchor
			)
		)
	end
	if #allTagged(SceneConfig.tags.hookOrigin, "Attachment", scene) > 1 then
		table.insert(
			issues,
			("Multiple '%s'-tagged attachments; hook-origin resolution is ambiguous — keep one."):format(
				SceneConfig.tags.hookOrigin
			)
		)
	end

	if not SceneContract.getCameraAnchor() then
		table.insert(
			issues,
			"No CameraAnchor (tag/name); the camera falls back to the SceneConfig pose."
		)
	end

	local seats = SceneContract.getBoatAnchors()
	if #seats == 0 then
		table.insert(issues, "No BoatAnchor Seat (tag/name); players cannot be seated.")
	else
		for _, seat in seats do
			if not seat.Anchored then
				table.insert(
					issues,
					("BoatAnchor Seat '%s' is NOT Anchored — a seated player stays client-simulated and could be driven off the plane. Anchor it."):format(
						seat:GetFullName()
					)
				)
			end
		end
	end

	local hook = SceneContract.getHookOrigin()
	if not hook then
		table.insert(
			issues,
			"No HookOrigin Attachment (tag/name); the fishing line has no authored origin."
		)
	elseif math.abs(hook.WorldPosition.Z - SceneConfig.gameplayPlaneZ) > 1e-3 then
		table.insert(
			issues,
			("HookOrigin is off the gameplay plane (Z=%.3f, expected %.3f) — keep it on gameplayPlaneZ."):format(
				hook.WorldPosition.Z,
				SceneConfig.gameplayPlaneZ
			)
		)
	end

	if #SceneContract.getBoatSpawns() == 0 then
		table.insert(issues, "No BoatSpawn (tag/name); players may not spawn on the boat.")
	end

	-- Depth bands: match each config layer to a tagged folder by its Index
	-- attribute, so a renamed or re-nested band folder still resolves.
	local bands = SceneContract.getPlaneLayers()
	if #bands == 0 then
		table.insert(
			issues,
			("No depth-band folders (tag/name); the %s are missing."):format(
				SceneConfig.planeLayersFolderName
			)
		)
	else
		local byIndex: { [number]: Instance } = {}
		for _, folder in bands do
			local idx = folder:GetAttribute("Index")
			if typeof(idx) == "number" then
				byIndex[idx :: number] = folder
			end
		end
		for index, layer in SceneConfig.layers do
			local folder = byIndex[index]
			if not folder then
				table.insert(
					issues,
					("Depth layer %d ('%s') has no band folder with Index=%d."):format(
						index,
						layer.name,
						index
					)
				)
			elseif
				folder:GetAttribute("Z") ~= layer.z
				or folder:GetAttribute("YTop") ~= layer.yTop
				or folder:GetAttribute("YBottom") ~= layer.yBottom
			then
				table.insert(
					issues,
					("Depth layer '%s' has drifted from SceneConfig. Re-run scene/BuildScene.luau."):format(
						layer.name
					)
				)
			end
		end
	end

	return issues
end

return SceneContract
