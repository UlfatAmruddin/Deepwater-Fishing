--!strict
-- Boot-time diagnostics for the authored 2.5D scene.
--
-- The playable scene (boat, seat, camera anchor, depth layers) is authored data
-- in the place file, built by scene/BuildScene.luau — it is NOT synced by Rojo.
-- Because SceneConfig.luau (the runtime source of truth) and BuildScene.luau
-- (the authored copy) are maintained by hand, they can silently drift, and a
-- freshly rojo-built place has no scene at all. This validator turns those
-- silent failures into loud, actionable warnings at server start.
--
-- It never errors: a developer editing the scene should get guidance, not a
-- crash. Every problem is a warning that names what is wrong and how to fix it.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)
local Log = require(Shared.Util.Log)

local SceneValidator = {}

local CAMERA_ANCHOR_NAME = "CameraAnchor"
local LAYERS_FOLDER_NAME = "Layers"

local function validateLayers(scene: Instance)
	local layersFolder = scene:FindFirstChild(LAYERS_FOLDER_NAME)
	if not layersFolder then
		Log.warn(
			("Scene '%s' has no '%s' folder; depth bands are missing."):format(
				SceneConfig.sceneName,
				LAYERS_FOLDER_NAME
			)
		)
		return
	end

	for index, layer in SceneConfig.layers do
		local folder = layersFolder:FindFirstChild(layer.name)
		if folder then
			if
				folder:GetAttribute("Z") ~= layer.z
				or folder:GetAttribute("YTop") ~= layer.yTop
				or folder:GetAttribute("YBottom") ~= layer.yBottom
			then
				Log.warn(
					("Depth layer '%s' has drifted from SceneConfig. Re-run scene/BuildScene.luau."):format(
						layer.name
					)
				)
			end
		else
			Log.warn(
				("Depth layer '%s' (index %d) is in SceneConfig but missing from the scene."):format(
					layer.name,
					index
				)
			)
		end
	end
end

function SceneValidator.validate()
	local scene = Workspace:FindFirstChild(SceneConfig.sceneName)
	if not scene then
		Log.warn(
			("Scene '%s' not found in Workspace. A rojo-built place ships scripts only — "):format(
				SceneConfig.sceneName
			) .. "run scene/BuildScene.luau in the Studio command bar to build the scene."
		)
		return
	end

	local cameraAnchor = scene:FindFirstChild(CAMERA_ANCHOR_NAME, true)
	if not (cameraAnchor and cameraAnchor:IsA("BasePart")) then
		Log.warn(
			("Scene '%s' has no '%s' BasePart; camera will use the SceneConfig fallback pose."):format(
				SceneConfig.sceneName,
				CAMERA_ANCHOR_NAME
			)
		)
	end

	local boatAnchor = scene:FindFirstChild(SceneConfig.boatAnchorName, true)
	if not boatAnchor then
		Log.warn(
			("Boat anchor '%s' not found in scene '%s'; players cannot be anchored."):format(
				SceneConfig.boatAnchorName,
				SceneConfig.sceneName
			)
		)
	elseif not boatAnchor:IsA("Seat") then
		Log.warn(
			("Boat anchor '%s' is a %s, not a Seat — players will be hard-anchored (standing), not seated."):format(
				SceneConfig.boatAnchorName,
				boatAnchor.ClassName
			)
		)
	elseif not boatAnchor.Anchored then
		-- A non-anchored Seat leaves the seated character client-simulated, so a
		-- hacked client could drive it off the plane despite the server seating it.
		Log.warn(
			("Boat anchor Seat '%s' is NOT Anchored — a seated player stays client-simulated and could be driven off the plane. Anchor the Seat."):format(
				SceneConfig.boatAnchorName
			)
		)
	end

	validateLayers(scene)

	Log.info("Scene validated:", SceneConfig.sceneName)
end

return SceneValidator
