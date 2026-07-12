--!strict
-- Central tunables + server-validation tolerances.
--
-- Pure data, chosen to be easy to rebalance. Later gameplay stages read these;
-- nothing here implements a system. Keeping the numbers in one place lets the
-- balancing pass (a later stage) tune the whole loop without touching services.

local Types = require(script.Parent.Parent.Types)

local BalanceConfig: Types.BalanceConfig = {
	castCooldown = 0.75, -- seconds a player must wait between casts
	runTimeout = 30, -- max seconds a single fishing run may last
	maxInputRate = 20, -- max steering inputs/second accepted per player
	maxOfflineDuration = 8 * 3600, -- cap on the offline-earnings window (seconds)
	upgradeCostGrowth = 1.5, -- exponential cost multiplier per upgrade level
	startingCoins = 0, -- coins a brand-new profile begins with

	-- Slack the server allows when reconciling client-reported timing/position.
	tolerances = {
		position = 2, -- studs
		time = 0.25, -- seconds
	},
}

return BalanceConfig
