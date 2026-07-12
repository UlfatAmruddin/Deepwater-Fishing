--!strict
-- Upgrade definitions (data). Only LineLength exists at this stage; the other
-- upgrades (HookCapacity, Luck, ReelControl) arrive with the upgrade service.
--
-- LineLength maps a level to the reachable normalized depth:
--   reach = clamp(effectBase + level * effectPerLevel, 0, 1)
-- so level 0 reaches 0.2 and level 10 reaches 1.0. Cost per level is
-- Math.exponentialCost(baseCost, BalanceConfig.upgradeCostGrowth, level).
--
-- The full 1.0 reach targets the whole MULTI-ZONE game; the fishing service will
-- clamp usable reach to the active zone's maxDepth (Sunny Shallows caps at 0.85),
-- so early levels are not "wasted" once deeper zones exist. A leaf data module
-- (no requires) so it loads headlessly for the validation tests.

return {
	{
		id = "LineLength",
		displayName = "Line Length",
		description = "Reach deeper water.",
		maxLevel = 10,
		baseCost = 25,
		effectBase = 0.2,
		effectPerLevel = 0.08,
	},
}
