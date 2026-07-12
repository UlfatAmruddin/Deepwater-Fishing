--!strict
-- Single source of truth for the 2.5D presentation layout.
--
-- IMPORTANT: scene/BuildScene.luau (the Studio scene builder) mirrors these
-- values so the authored scene and the runtime camera agree. If you change a
-- number here, update that script too.

local Types = require(script.Parent.Parent.Types)

local SceneConfig: Types.SceneConfig = {
	sceneName = "DeepwaterScene",
	boatAnchorName = "BoatAnchor",
	cameraAnchorName = "CameraAnchor",
	hookOriginName = "HookOrigin",
	boatSpawnsFolderName = "BoatSpawns",
	planeLayersFolderName = "PlaneLayers",
	contractVersion = 1,

	-- Asset-replacement contract: gameplay resolves scene parts by these tags
	-- (via SceneContract), so any tagged custom model can replace a placeholder
	-- without gameplay code changes. Mirrored in scene/BuildScene.luau.
	tags = {
		scene = "DwScene",
		cameraAnchor = "DwCameraAnchor",
		boatAnchor = "DwBoatAnchor",
		hookOrigin = "DwHookOrigin",
		boatSpawn = "DwBoatSpawn",
		planeLayer = "DwPlaneLayer",
	},

	-- All gameplay (boat, hook, line, caught fish) lives on this Z plane.
	gameplayPlaneZ = 0,

	-- Horizontal reach of the logical gameplay plane (world X). The hook is
	-- clamped to this by PlaneSpace, so gameplay can never wander off the plane.
	planeBounds = { xMin = -30, xMax = 30 },

	camera = {
		position = Vector3.new(0, 8, 28),
		lookAt = Vector3.new(0, 4, 0),
		fieldOfView = 55,
		-- Bounded pan only. These caps keep the "camera" feeling fixed.
		panX = { min = -6, max = 6 },
		panY = { min = -3, max = 3 },
		panLerp = 0.15,
	},

	-- Depth bands from surface to deepwater. `z` is a purely visual parallax
	-- plane behind the gameplay plane; it does not move gameplay off Z = 0.
	layers = {
		{ name = "Surface", z = 0, yTop = 4, yBottom = -6 },
		{ name = "Shallows", z = -2, yTop = -6, yBottom = -22 },
		{ name = "Midwater", z = -4, yTop = -22, yBottom = -44 },
		{ name = "Deepwater", z = -6, yTop = -44, yBottom = -72 },
	},
}

return SceneConfig
