--!strict
-- Global, non-gameplay constants. Kept intentionally tiny in Stage 0.

local GameConfig = {
	gameName = "Deepwater Fishing",

	-- Namespace for the (future) player data store. Bumping this string
	-- migrates everyone to a fresh save — never change it casually.
	dataStoreScope = "prod-v1",
}

return GameConfig
