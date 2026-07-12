--!strict
-- Content registry — the single validated, frozen source of game content.
--
-- Requires the raw leaf data modules, validates them (unique ids, cross-refs,
-- ranges) and FAILS FAST on invalid content, freezes them, and exposes typed
-- getters. Asset references route through AssetManifest (Content.assets /
-- Content.getAsset), so gameplay never hardcodes an asset id. Services and UI
-- read content ONLY through this registry.

-- `Content/init.luau` makes Content a ModuleScript, so the data modules are its
-- CHILDREN (script.X); Types lives one level up in Shared (script.Parent.Types).
local Types = require(script.Parent.Types)
local validate = require(script.validate)
local AssetManifest = require(script.AssetManifest)

local fish: { Types.FishDefinition } = require(script.Fish)
local zones: { Types.ZoneDefinition } = require(script.Zones)
local upgrades: { Types.UpgradeDefinition } = require(script.Upgrades)
local rarities: { Types.RarityTier } = require(script.Rarity)

local issues = validate({ fish = fish, zones = zones, upgrades = upgrades, rarities = rarities })
assert(#issues == 0, "Content validation failed:\n  " .. table.concat(issues, "\n  "))

local function indexById<T>(list: { T }): { [string]: T }
	local byId: { [string]: T } = {}
	for _, item in list do
		byId[(item :: any).id :: string] = item
	end
	return byId
end

-- Deep-freeze so definition rows AND their nested Range subtables are immutable,
-- not just the outer arrays (table.freeze is shallow). Getters hand out live
-- shared references, so a later service mutating one would corrupt content for
-- every player; deep-freezing turns that into an error.
local function deepFreeze(value: any)
	if type(value) == "table" then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
end

deepFreeze(fish)
deepFreeze(zones)
deepFreeze(upgrades)
deepFreeze(rarities)

local fishById = table.freeze(indexById(fish))
local zoneById = table.freeze(indexById(zones))
local upgradeById = table.freeze(indexById(upgrades))
local rarityById = table.freeze(indexById(rarities))

local Content = {}

-- The asset-replacement manifest, so content consumers reach assets through one
-- authority rather than hardcoding ids.
Content.assets = AssetManifest

function Content.getAllFish(): { Types.FishDefinition }
	return fish
end

function Content.getFish(id: string): Types.FishDefinition?
	return fishById[id]
end

function Content.getZone(id: string): Types.ZoneDefinition?
	return zoneById[id]
end

function Content.getUpgrade(id: string): Types.UpgradeDefinition?
	return upgradeById[id]
end

function Content.getRarity(id: string): Types.RarityTier?
	return rarityById[id]
end

-- Resolve an asset-replacement entry by role (e.g. "Fish", "Boat") through the
-- AssetManifest, preserving the asset-replacement contract.
function Content.getAsset(role: string): Types.AssetManifestEntry?
	for _, entry in AssetManifest do
		if entry.role == role then
			return entry
		end
	end
	return nil
end

return Content
