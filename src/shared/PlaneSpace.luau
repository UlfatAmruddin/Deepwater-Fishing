--!strict
-- PlaneSpace — the pure mathematical embodiment of the 2.5D contract.
--
-- Gameplay lives in TWO scalars: `x` (world X, bounded) and `depth` (normalized
-- 0..1, mapped to world Y through the authored layer band extents). There is NO
-- z in the gameplay coordinate; `toWorld` stamps the fixed gameplayPlaneZ, so no
-- caller can place gameplay off the plane.
--
-- This module is PURE: it holds no state, requires no other module, and touches
-- no Roblox instances or datatypes. Every function takes a plain `PlaneSpec`
-- (built by the caller from SceneConfig), which keeps PlaneSpace headlessly
-- unit-testable under Lune. In-engine callers wrap `toWorld`'s {x,y,z} result in
-- a Vector3 at the point of placement.

local PlaneSpace = {}

export type PlaneVec2 = {
	x: number, -- world X on the plane
	depth: number, -- normalized descent, 0 (surface) .. 1 (deepest)
}

export type PlaneBand = {
	yTop: number, -- world Y at the top of the band
	yBottom: number, -- world Y at the bottom of the band
}

export type PlaneSpec = {
	gameplayPlaneZ: number,
	xMin: number,
	xMax: number,
	bands: { PlaneBand }, -- ordered surface -> deepest
}

export type PlaneSpeeds = {
	x: number, -- world studs / second of horizontal steer
	depth: number, -- normalized depth / second of reel
}

local function clampNumber(value: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, value))
end

function PlaneSpace.surfaceY(spec: PlaneSpec): number
	return spec.bands[1].yTop
end

function PlaneSpace.floorY(spec: PlaneSpec): number
	return spec.bands[#spec.bands].yBottom
end

function PlaneSpace.clampX(x: number, spec: PlaneSpec): number
	return clampNumber(x, spec.xMin, spec.xMax)
end

-- Clamp a normalized depth to [0, min(1, maxDepth01)]. `maxDepth01` is the reach
-- granted by the LineLength upgrade, so upgrades widen the reachable plane.
function PlaneSpace.clampDepth(depth01: number, maxDepth01: number): number
	return clampNumber(depth01, 0, math.min(1, maxDepth01))
end

function PlaneSpace.clamp(p: PlaneVec2, spec: PlaneSpec, maxDepth01: number): PlaneVec2
	return {
		x = PlaneSpace.clampX(p.x, spec),
		depth = PlaneSpace.clampDepth(p.depth, maxDepth01),
	}
end

-- Map a normalized depth (0..1) to world Y across the full band range.
function PlaneSpace.depthToWorldY(depth01: number, spec: PlaneSpec): number
	local top = PlaneSpace.surfaceY(spec)
	local bottom = PlaneSpace.floorY(spec)
	return top + (bottom - top) * clampNumber(depth01, 0, 1)
end

-- Inverse of depthToWorldY: world Y to a normalized depth (0..1).
function PlaneSpace.worldYToDepth(y: number, spec: PlaneSpec): number
	local top = PlaneSpace.surfaceY(spec)
	local bottom = PlaneSpace.floorY(spec)
	if top == bottom then
		return 0
	end
	return clampNumber((y - top) / (bottom - top), 0, 1)
end

-- 1-based index of the layer band a normalized depth falls in (clamped to ends).
function PlaneSpace.layerIndexForDepth(depth01: number, spec: PlaneSpec): number
	local y = PlaneSpace.depthToWorldY(depth01, spec)
	for i, band in spec.bands do
		if y <= band.yTop and y >= band.yBottom then
			return i
		end
	end
	return #spec.bands
end

-- Integrate a normalized steering intent into a new plane position, clamped so
-- the result can never leave the plane. `steerX`/`reel` are intents in [-1, 1];
-- the caller owns `speeds` (server-authoritative), so a tampered client can only
-- ever send a unit intent that is still clamped and still on-plane.
function PlaneSpace.applyInput(
	p: PlaneVec2,
	steerX: number,
	reel: number,
	dt: number,
	speeds: PlaneSpeeds,
	spec: PlaneSpec,
	maxDepth01: number
): PlaneVec2
	local sx = clampNumber(steerX, -1, 1)
	local rr = clampNumber(reel, -1, 1)
	local moved: PlaneVec2 = {
		x = p.x + sx * speeds.x * dt,
		depth = p.depth + rr * speeds.depth * dt,
	}
	return PlaneSpace.clamp(moved, spec, maxDepth01)
end

-- Convert a plane position to a world position on the fixed gameplay Z plane.
-- Returns a plain table (no Vector3), so PlaneSpace stays pure/testable; callers
-- wrap it in Vector3.new at placement time.
function PlaneSpace.toWorld(p: PlaneVec2, spec: PlaneSpec): { x: number, y: number, z: number }
	return {
		x = PlaneSpace.clampX(p.x, spec),
		y = PlaneSpace.depthToWorldY(p.depth, spec),
		z = spec.gameplayPlaneZ,
	}
end

return PlaneSpace
