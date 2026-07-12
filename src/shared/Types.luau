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

-- CollectionService tag names for the asset-replacement contract. Gameplay
-- resolves scene parts by these tags (tag-first, name-fallback) so a custom
-- model can be swapped in without touching gameplay code.
export type TagSet = {
	scene: string, -- the DeepwaterScene root Model
	cameraAnchor: string, -- the BasePart whose CFrame is the fixed camera pose
	boatAnchor: string, -- the Seat(s) players are seated on
	hookOrigin: string, -- the Attachment the line/hook pays out from
	boatSpawn: string, -- the SpawnLocation(s) that spawn players on a boat
	planeLayer: string, -- the depth-band folders (Index/Z/YTop/YBottom attrs)
}

-- The complete authored scene contract shared by the client camera and the
-- Studio scene-build script. Names are the human-friendly fallback; the `tags`
-- are the stable, position-independent contract used by SceneContract.
export type SceneConfig = {
	sceneName: string,
	boatAnchorName: string,
	cameraAnchorName: string,
	hookOriginName: string,
	boatSpawnsFolderName: string,
	planeLayersFolderName: string,
	contractVersion: number, -- stamped on the scene root for future migrations
	tags: TagSet,
	gameplayPlaneZ: number, -- the single Z plane all gameplay stays on
	camera: CameraConfig,
	layers: { DepthLayer },
}

-- One replaceable production asset. The manifest maps a logical role to the
-- contract a custom replacement must satisfy (never mesh names, child indices,
-- dimensions, or a specific PrimaryPart).
export type AssetManifestEntry = {
	role: string, -- "Boat", "CameraAnchor", "Hook", "Fish", "Prop", "UI"
	description: string,
	placeholder: string, -- where the placeholder comes from
	requiredTags: { string }, -- CollectionService tags the replacement must carry
	requiredAttributes: { string }, -- attribute keys it must expose
	requiredChildren: { string }, -- required child instance kinds (e.g. "Seat")
	movesInPlane: boolean, -- may move in X/Y (hook/fish) vs anchored presentation
	replacement: string, -- one-line replacement note; full steps in ASSET_REPLACEMENT.md
}

return Types
