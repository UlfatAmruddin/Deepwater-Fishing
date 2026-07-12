--!strict
-- Original fish species for the Sunny Shallows zone (data).
--
-- `depthRange` is NORMALIZED (0..1), never a world Z. `sizeRange` is centimetres.
-- `baseValue` is a RARITY-NEUTRAL species/size coin base — the rarity premium is
-- applied once via RarityTier.valueMultiplier (final value = baseValue *
-- valueMultiplier * sizeFactor), so the economy stage never double-counts rarity.
-- `aquariumValue` is a separate passive-income lever. All original names/ids.
-- A leaf data module (no requires) so it loads headlessly for the tests.

return {
	{
		id = "pebble_minnow",
		displayName = "Pebble Minnow",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.0, max = 0.2 },
		rarity = "common",
		baseValue = 4,
		sizeRange = { min = 3, max = 8 },
		aquariumValue = 1,
	},
	{
		id = "sunscale_perch",
		displayName = "Sunscale Perch",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.05, max = 0.35 },
		rarity = "common",
		baseValue = 8,
		sizeRange = { min = 8, max = 18 },
		aquariumValue = 2,
	},
	{
		id = "reed_darter",
		displayName = "Reed Darter",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.15, max = 0.45 },
		rarity = "uncommon",
		baseValue = 9,
		sizeRange = { min = 9, max = 20 },
		aquariumValue = 4,
	},
	{
		id = "glimmer_bream",
		displayName = "Glimmer Bream",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.2, max = 0.55 },
		rarity = "uncommon",
		baseValue = 12,
		sizeRange = { min = 12, max = 26 },
		aquariumValue = 6,
	},
	{
		id = "copper_bass",
		displayName = "Copper Bass",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.3, max = 0.65 },
		rarity = "rare",
		baseValue = 20,
		sizeRange = { min = 20, max = 40 },
		aquariumValue = 12,
	},
	{
		id = "amber_koi",
		displayName = "Amber Koi",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.45, max = 0.75 },
		rarity = "epic",
		baseValue = 28,
		sizeRange = { min = 25, max = 50 },
		aquariumValue = 26,
	},
	{
		id = "gilded_sunfish",
		displayName = "Gilded Sunfish",
		zoneId = "sunny_shallows",
		depthRange = { min = 0.55, max = 0.85 },
		rarity = "legendary",
		baseValue = 40,
		sizeRange = { min = 30, max = 60 },
		aquariumValue = 60,
	},
}
