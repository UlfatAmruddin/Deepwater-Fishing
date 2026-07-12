--!strict
-- Zone definitions (data). Only Sunny Shallows exists at this stage — later zones
-- (Kelp Forest, Coral Canyon) arrive with the zone system. `maxDepth` is the
-- deepest normalized depth (0..1) reachable here. A leaf data module (no
-- requires) so it loads headlessly for the validation tests.

return {
	{
		id = "sunny_shallows",
		displayName = "Sunny Shallows",
		maxDepth = 0.85,
		unlockCost = 0, -- the free starter zone
	},
}
