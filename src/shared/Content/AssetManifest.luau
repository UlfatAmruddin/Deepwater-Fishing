--!strict
-- Asset-replacement manifest.
--
-- Maps each logical production-art ROLE to the contract a custom replacement
-- must satisfy — expressed as CollectionService tags, attributes, and required
-- child kinds, NEVER as mesh names, child indices, exact dimensions, or a
-- specific PrimaryPart. Gameplay resolves these via shared/SceneContract, so a
-- swapped-in model that keeps its tags works with no gameplay-code change.
--
-- This is the machine-readable half of the contract; the human checklist lives
-- in docs/ASSET_REPLACEMENT.md. Fish/Hook rows are forward-looking (their
-- visuals arrive with the fishing stages) but their plane/tag rules are fixed
-- now so later art lands against a stable contract.

local Types = require(script.Parent.Parent.Types)
local SceneConfig = require(script.Parent.Parent.Config.SceneConfig)

local tags = SceneConfig.tags

local AssetManifest: { Types.AssetManifestEntry } = {
	{
		role = "Scene",
		description = "The DeepwaterScene root model that contains all authored presentation.",
		placeholder = "scene/BuildScene.luau builds it in the Studio command bar.",
		requiredTags = { tags.scene },
		requiredAttributes = { "ContractVersion" },
		requiredChildren = {
			"CameraAnchor",
			"Boat/Seat",
			"HookOrigin",
			"BoatSpawns",
			"PlaneLayers",
		},
		movesInPlane = false,
		replacement = "Keep the tag on the root Model; children are resolved by tag, not by hierarchy position.",
	},
	{
		role = "CameraAnchor",
		description = "Invisible BasePart whose CFrame is the fixed 2.5D camera pose.",
		placeholder = "1x1x1 transparent Part at the SceneConfig camera pose.",
		requiredTags = { tags.cameraAnchor },
		requiredAttributes = {},
		requiredChildren = {},
		movesInPlane = false,
		replacement = "Any BasePart works; only its CFrame is read. Size/shape/mesh are irrelevant.",
	},
	{
		role = "Boat",
		description = "Anchored presentation hull the player sits on. Purely visual except for its contract children.",
		placeholder = "Anchored wood-plank Part hull with a Seat and a HookOrigin attachment.",
		requiredTags = { tags.boatAnchor, tags.hookOrigin },
		requiredAttributes = {},
		requiredChildren = {
			"Seat (Anchored, tagged " .. tags.boatAnchor .. ")",
			"Attachment (tagged " .. tags.hookOrigin .. ")",
		},
		movesInPlane = false,
		replacement = "Swap the hull for any mesh. Keep an ANCHORED Seat tagged "
			.. tags.boatAnchor
			.. " and an Attachment tagged "
			.. tags.hookOrigin
			.. ". No PrimaryPart requirement.",
	},
	{
		role = "BoatSpawn",
		description = "SpawnLocation(s) that place joining players on a boat (server still hard-seats them).",
		placeholder = "Transparent, non-colliding SpawnLocation(s) under the BoatSpawns folder.",
		requiredTags = { tags.boatSpawn },
		requiredAttributes = {},
		requiredChildren = {},
		movesInPlane = false,
		replacement = "Provide one tagged SpawnLocation per authored boat; keep them anchored and non-colliding.",
	},
	{
		role = "PlaneLayer",
		description = "Depth-band folders carrying Index/Z/YTop/YBottom attributes that map normalized depth to world Y.",
		placeholder = "One folder per band (Surface..Deepwater) with a visual Band part.",
		requiredTags = { tags.planeLayer },
		requiredAttributes = { "Index", "Z", "YTop", "YBottom" },
		requiredChildren = {},
		movesInPlane = false,
		replacement = "Restyle the Band visuals freely; the ATTRIBUTES are the contract and must match SceneConfig.layers.",
	},
	{
		role = "Hook",
		description = "The line hook the player steers. Created at runtime on the gameplay plane; not authored in the scene.",
		placeholder = "None yet — a runtime Part on Z = gameplayPlaneZ (arrives with the fishing stages).",
		requiredTags = {},
		requiredAttributes = {},
		requiredChildren = {},
		movesInPlane = true,
		replacement = "Provide a hook template; it is positioned only via PlaneSpace (X/Y, fixed Z). Never give it free 3D motion.",
	},
	{
		role = "Fish",
		description = "Fish visuals shown during a run. Positioned in plane space from server-sent logical coordinates.",
		placeholder = "None yet — arrives with the fishing stages.",
		requiredTags = {},
		requiredAttributes = {},
		requiredChildren = {},
		movesInPlane = true,
		replacement = "Any model/icon; it is placed via PlaneSpace on the gameplay plane. Visual size maps from normalized size, not authored dimensions.",
	},
	{
		role = "UI",
		description = "HUD, shop, results, and other screens.",
		placeholder = "Code-built ScreenGuis created into PlayerGui by the client UI modules (no StarterGui authoring).",
		requiredTags = {},
		requiredAttributes = {},
		requiredChildren = {},
		movesInPlane = false,
		replacement = "Restyle within the UI modules; all displayed values come from server snapshots.",
	},
}

return AssetManifest
