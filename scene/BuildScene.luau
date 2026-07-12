--!nocheck
-- Deepwater Fishing - Studio scene builder (reproducible 2.5D scene).
--
-- HOW TO RUN (no plugin required):
--   1. Open a fresh Baseplate in Roblox Studio (File > New, "Baseplate").
--   2. View > Command Bar.
--   3. Paste the ENTIRE contents of this file and press Enter.
--   4. File > Save (or Publish), then start Rojo sync to inject the scripts.
--
-- The script is idempotent: run it again to rebuild the scene cleanly.
-- Values + tag names below MIRROR src/shared/Config/SceneConfig.luau - keep them
-- in sync. Gameplay resolves every part below by its CollectionService TAG (via
-- shared/SceneContract), never by mesh name, child index, dimension, or
-- PrimaryPart, so a custom model that keeps these tags can replace a placeholder
-- with no gameplay-code change. See docs/ASSET_REPLACEMENT.md.
--
-- What it produces under Workspace.DeepwaterScene (tag in brackets):
--   * [DwScene]        the scene root Model (ContractVersion attribute)
--   * CameraAnchor     [DwCameraAnchor] invisible part = fixed camera pose
--   * Boat/Hull        anchored hull (visual only)
--   * Boat/BoatAnchor  [DwBoatAnchor] anchored Seat = the seat point
--   * Boat/HookOrigin  [DwHookOrigin] Attachment = where the line pays out
--   * BoatSpawns/BoatSpawn_1 [DwBoatSpawn] SpawnLocation
--   * Water            anchored, non-colliding visual water column
--   * PlaneLayers/<Surface..Deepwater> [DwPlaneLayer] folders w/ Index/Z/YTop/YBottom

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local SCENE_NAME = "DeepwaterScene"
local BOAT_ANCHOR_NAME = "BoatAnchor"
local CAMERA_ANCHOR_NAME = "CameraAnchor"
local HOOK_ORIGIN_NAME = "HookOrigin"
local BOAT_SPAWNS_FOLDER_NAME = "BoatSpawns"
local PLANE_LAYERS_FOLDER_NAME = "PlaneLayers"
local CONTRACT_VERSION = 1

local TAG_SCENE = "DwScene"
local TAG_CAMERA_ANCHOR = "DwCameraAnchor"
local TAG_BOAT_ANCHOR = "DwBoatAnchor"
local TAG_HOOK_ORIGIN = "DwHookOrigin"
local TAG_BOAT_SPAWN = "DwBoatSpawn"
local TAG_PLANE_LAYER = "DwPlaneLayer"

local CAMERA_POSITION = Vector3.new(0, 8, 28)
local CAMERA_LOOKAT = Vector3.new(0, 4, 0)
local HOOK_ORIGIN_WORLD = Vector3.new(0, 4.5, 0) -- on the gameplay plane (Z = 0)

local LAYERS = {
	{ name = "Surface", z = 0, yTop = 4, yBottom = -6 },
	{ name = "Shallows", z = -2, yTop = -6, yBottom = -22 },
	{ name = "Midwater", z = -4, yTop = -22, yBottom = -44 },
	{ name = "Deepwater", z = -6, yTop = -44, yBottom = -72 },
}

local function anchoredPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

-- Fresh start: drop any previous scene (old OR new name), the default baseplate,
-- and stray spawns.
for _, name in { SCENE_NAME, "Scene", "DeepwaterWorld" } do
	local previous = Workspace:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end
end
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("SpawnLocation") then
		descendant:Destroy()
	end
end

-- Keep the whole fixed scene loaded; no streaming for a small authored space.
Workspace.StreamingEnabled = false

local scene = Instance.new("Model")
scene.Name = SCENE_NAME
scene:SetAttribute("ContractVersion", CONTRACT_VERSION)
CollectionService:AddTag(scene, TAG_SCENE)

-- Fixed camera pose (client reads this CFrame).
local cameraAnchor = anchoredPart({
	Name = CAMERA_ANCHOR_NAME,
	Size = Vector3.new(1, 1, 1),
	Transparency = 1,
	CFrame = CFrame.lookAt(CAMERA_POSITION, CAMERA_LOOKAT),
})
CollectionService:AddTag(cameraAnchor, TAG_CAMERA_ANCHOR)
cameraAnchor.Parent = scene

-- Visual water column (anchored, non-colliding).
local water = anchoredPart({
	Name = "Water",
	Size = Vector3.new(80, 80, 1),
	Position = Vector3.new(0, -36, -1),
	Color = Color3.fromRGB(24, 74, 110),
	Transparency = 0.35,
	Material = Enum.Material.Glass,
})
water.Parent = scene

-- Boat hull + the Seat that names the anchor point + the hook-origin attachment.
local boat = Instance.new("Model")
boat.Name = "Boat"

local hull = anchoredPart({
	Name = "Hull",
	Size = Vector3.new(14, 3, 6),
	Position = Vector3.new(0, 3, 0),
	Color = Color3.fromRGB(120, 78, 46),
	Material = Enum.Material.WoodPlanks,
})
hull.Parent = boat

local seat = Instance.new("Seat")
seat.Name = BOAT_ANCHOR_NAME
seat.Anchored = true -- REQUIRED: an anchored seat keeps the seated character server-authoritative.
seat.CanCollide = false
seat.Size = Vector3.new(2, 1, 2)
seat.Position = Vector3.new(0, 5, 0)
CollectionService:AddTag(seat, TAG_BOAT_ANCHOR)
seat.Parent = boat

local hookOrigin = Instance.new("Attachment")
hookOrigin.Name = HOOK_ORIGIN_NAME
hookOrigin.Parent = hull
hookOrigin.WorldPosition = HOOK_ORIGIN_WORLD
CollectionService:AddTag(hookOrigin, TAG_HOOK_ORIGIN)

boat.PrimaryPart = hull -- convenience for authoring only; gameplay never reads PrimaryPart.
boat.Parent = scene

-- Spawn players on the boat (server still hard-seats them). Under a folder so
-- the seat pool can grow to N boats later.
local spawns = Instance.new("Folder")
spawns.Name = BOAT_SPAWNS_FOLDER_NAME
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "BoatSpawn_1"
spawnLocation.Anchored = true
spawnLocation.CanCollide = false
spawnLocation.Transparency = 1
spawnLocation.Size = Vector3.new(4, 1, 4)
spawnLocation.Position = Vector3.new(0, 6, 0)
spawnLocation.Neutral = true
CollectionService:AddTag(spawnLocation, TAG_BOAT_SPAWN)
spawnLocation.Parent = spawns
spawns.Parent = scene

-- Depth layer folders (locked Z parallax planes; gameplay stays on Z = 0).
local layers = Instance.new("Folder")
layers.Name = PLANE_LAYERS_FOLDER_NAME
for index, layer in LAYERS do
	local folder = Instance.new("Folder")
	folder.Name = layer.name
	folder:SetAttribute("Index", index)
	folder:SetAttribute("Z", layer.z)
	folder:SetAttribute("YTop", layer.yTop)
	folder:SetAttribute("YBottom", layer.yBottom)
	CollectionService:AddTag(folder, TAG_PLANE_LAYER)

	local band = anchoredPart({
		Name = "Band",
		Size = Vector3.new(80, layer.yTop - layer.yBottom, 1),
		Position = Vector3.new(0, (layer.yTop + layer.yBottom) / 2, layer.z - 2),
		Color = Color3.fromRGB(18, 54, 82):Lerp(Color3.fromRGB(4, 16, 30), index / #LAYERS),
		Transparency = 0.15,
		Material = Enum.Material.SmoothPlastic,
	})
	band.Parent = folder

	folder.Parent = layers
end
layers.Parent = scene

scene.Parent = Workspace

-- Harbor mood lighting (tweak freely).
Lighting.Ambient = Color3.fromRGB(70, 90, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(90, 110, 130)
Lighting.Brightness = 2

print(
	("[Deepwater] Built '%s' (contract v%d) with %d depth layers, tagged for asset replacement."):format(
		SCENE_NAME,
		CONTRACT_VERSION,
		#LAYERS
	)
)
