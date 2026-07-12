--!strict
-- Rarity tiers (data). Weights drive weighted selection (they need not sum to
-- 100 — Math.weightedIndex normalizes); valueMultiplier scales economy value in
-- a later stage. A leaf data module (no requires) so it loads headlessly for the
-- content-validation tests; the registry (Content/init) types + validates it.

return {
	{ id = "common", weight = 60, valueMultiplier = 1.0 },
	{ id = "uncommon", weight = 25, valueMultiplier = 1.6 },
	{ id = "rare", weight = 10, valueMultiplier = 3.0 },
	{ id = "epic", weight = 4, valueMultiplier = 6.0 },
	{ id = "legendary", weight = 1, valueMultiplier = 15.0 },
}
