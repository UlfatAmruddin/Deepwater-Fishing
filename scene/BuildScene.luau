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
-- Values below MIRROR src/shared/Config/SceneConfig.luau - keep them in sync.
--
-- What it produces under Workspace.DeepwaterScene:
--   * CameraAnchor  - invisible part whose CFrame is the fixed camera pose
--   * Boat          - anchored hull + a Seat named BoatAnchor (the seat point)
--   * BoatSpawn     - SpawnLocation on the boat so players start seated
--   * Water         - anchored, non-colliding visual water column
--   * Layers        - one Folder per depth band (Surface..Deepwater) carrying
--                     Index/Z/YTop/YBottom attributes + a visual Band part

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local SCENE_NAME = "DeepwaterScene"
local BOAT_ANCHOR_NAME = "BoatAnchor"
local CAMERA_ANCHOR_NAME = "CameraAnchor"

local CAMERA_POSITION = Vector3.new(0, 8, 28)
local CAMERA_LOOKAT = Vector3.new(0, 4, 0)

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

-- Fresh start: drop any previous scene, the default baseplate, and stray spawns.
local previous = Workspace:FindFirstChild(SCENE_NAME)
if previous then
	previous:Destroy()
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

-- Fixed camera pose (client reads this CFrame).
local cameraAnchor = anchoredPart({
	Name = CAMERA_ANCHOR_NAME,
	Size = Vector3.new(1, 1, 1),
	Transparency = 1,
	CFrame = CFrame.lookAt(CAMERA_POSITION, CAMERA_LOOKAT),
})
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

-- Boat hull + the Seat that names the anchor point.
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
seat.Anchored = true
seat.CanCollide = false
seat.Size = Vector3.new(2, 1, 2)
seat.Position = Vector3.new(0, 5, 0)
seat.Parent = boat

boat.PrimaryPart = hull
boat.Parent = scene

-- Spawn players directly on the boat (server still hard-anchors them).
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "BoatSpawn"
spawnLocation.Anchored = true
spawnLocation.CanCollide = false
spawnLocation.Transparency = 1
spawnLocation.Size = Vector3.new(4, 1, 4)
spawnLocation.Position = Vector3.new(0, 6, 0)
spawnLocation.Neutral = true
spawnLocation.Parent = scene

-- Depth layer folders (locked Z parallax planes; gameplay stays on Z = 0).
local layers = Instance.new("Folder")
layers.Name = "Layers"
for index, layer in LAYERS do
	local folder = Instance.new("Folder")
	folder.Name = layer.name
	folder:SetAttribute("Index", index)
	folder:SetAttribute("Z", layer.z)
	folder:SetAttribute("YTop", layer.yTop)
	folder:SetAttribute("YBottom", layer.yBottom)

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
	("[Deepwater] Built '%s' with %d depth layers. Boat anchor: %s"):format(
		SCENE_NAME,
		#LAYERS,
		BOAT_ANCHOR_NAME
	)
)
