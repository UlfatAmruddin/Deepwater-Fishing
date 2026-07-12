--!strict
-- Shared type definitions for Deepwater Fishing.
--
-- Stage 0 holds ONLY foundational presentation/config types. Gameplay types
-- (fish, inventory, currency, upgrades, fishing runs) are added with their
-- respective stages so this module never becomes a dumping ground.

local Types = {}

-- A closed numeric range, used for bounded camera pan offsets.
export type Range = {
	min: number,
	max: number,
}

-- Configuration for the single fixed 2.5D camera. Orientation is derived from
-- position -> lookAt and is CONSTANT; only a small bounded pan is permitted.
export type CameraConfig = {
	position: Vector3,
	lookAt: Vector3,
	fieldOfView: number,
	panX: Range, -- bounded horizontal pan offset (studs, camera-local)
	panY: Range, -- bounded vertical pan offset (studs, camera-local)
	panLerp: number, -- 0..1 smoothing applied per frame
}

-- A locked depth band. Fishing depth is presented as vertical travel (world Y)
-- plus discrete layer changes; gameplay never leaves the fixed X/Y plane.
export type DepthLayer = {
	name: string,
	z: number, -- background parallax plane for this band (visual only)
	yTop: number, -- top of the band (world Y, studs)
	yBottom: number, -- bottom of the band (world Y, studs)
}

-- The complete authored scene contract shared by the client camera and the
-- Studio scene-build script.
export type SceneConfig = {
	sceneName: string,
	boatAnchorName: string,
	gameplayPlaneZ: number, -- the single Z plane all gameplay stays on
	camera: CameraConfig,
	layers: { DepthLayer },
}

return Types
