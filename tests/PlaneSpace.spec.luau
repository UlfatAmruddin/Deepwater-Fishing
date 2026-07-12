-- Headless tests for the pure PlaneSpace 2.5D math. Run via Lune (see run.luau).

local PlaneSpace = require("../src/shared/PlaneSpace")

local passed = 0
local failed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print("  FAIL: " .. name)
	end
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local spec = {
	gameplayPlaneZ = 0,
	xMin = -30,
	xMax = 30,
	bands = {
		{ yTop = 4, yBottom = -6 },
		{ yTop = -6, yBottom = -22 },
		{ yTop = -22, yBottom = -44 },
		{ yTop = -44, yBottom = -72 },
	},
}

local MID_Y = (4 + -72) / 2

check("clampX clamps above max", PlaneSpace.clampX(100, spec) == 30)
check("clampX clamps below min", PlaneSpace.clampX(-100, spec) == -30)
check("clampDepth clamps to maxDepth", PlaneSpace.clampDepth(0.9, 0.5) == 0.5)
check("clampDepth clamps below 0", PlaneSpace.clampDepth(-1, 1) == 0)
check("clampDepth never exceeds 1", PlaneSpace.clampDepth(2, 5) == 1)

check("depthToWorldY(0) is the surface", approx(PlaneSpace.depthToWorldY(0, spec), 4))
check("depthToWorldY(1) is the floor", approx(PlaneSpace.depthToWorldY(1, spec), -72))
check("depthToWorldY(0.5) is the midpoint", approx(PlaneSpace.depthToWorldY(0.5, spec), MID_Y))

check(
	"worldYToDepth inverts depthToWorldY",
	approx(PlaneSpace.worldYToDepth(PlaneSpace.depthToWorldY(0.37, spec), spec), 0.37)
)
check("worldYToDepth(surface) is 0", approx(PlaneSpace.worldYToDepth(4, spec), 0))
check("worldYToDepth(floor) is 1", approx(PlaneSpace.worldYToDepth(-72, spec), 1))

check("layerIndexForDepth(0) is band 1", PlaneSpace.layerIndexForDepth(0, spec) == 1)
check("layerIndexForDepth(1) is the last band", PlaneSpace.layerIndexForDepth(1, spec) == 4)

-- applyInput clamps to plane bounds and reach.
do
	local fast = { x = 1000, depth = 1000 }
	local p = PlaneSpace.applyInput({ x = 0, depth = 0 }, 1, 1, 1, fast, spec, 0.6)
	check("applyInput clamps x to xMax", p.x == 30)
	check("applyInput clamps depth to maxDepth", approx(p.depth, 0.6))

	local q = PlaneSpace.applyInput({ x = 0, depth = 0.5 }, -1, -1, 1, fast, spec, 1)
	check("applyInput clamps x to xMin", q.x == -30)
	check("applyInput clamps depth to 0", q.depth == 0)
end

-- applyInput applies steer * speed * dt for normal movement.
do
	local speeds = { x = 10, depth = 0.1 }
	local p = PlaneSpace.applyInput({ x = 0, depth = 0.2 }, 1, 1, 0.5, speeds, spec, 1)
	check("applyInput moves x by steer*speed*dt", approx(p.x, 5))
	check("applyInput moves depth by reel*speed*dt", approx(p.depth, 0.25))
end

-- applyInput clamps out-of-range intents to [-1, 1].
do
	local speeds = { x = 10, depth = 0.1 }
	local hacked = PlaneSpace.applyInput({ x = 0, depth = 0.2 }, 999, 0, 1, speeds, spec, 1)
	check("applyInput clamps a hacked steer intent", hacked.x == 10)
end

-- toWorld stamps the fixed gameplay Z plane.
do
	local w = PlaneSpace.toWorld({ x = 12, depth = 0.5 }, spec)
	check("toWorld z is gameplayPlaneZ", w.z == 0)
	check("toWorld x is preserved", w.x == 12)
	check("toWorld y matches depth", approx(w.y, MID_Y))
	check(
		"toWorld clamps out-of-bounds x",
		PlaneSpace.toWorld({ x = 999, depth = 0.5 }, spec).x == 30
	)
end

return { passed = passed, failed = failed }
