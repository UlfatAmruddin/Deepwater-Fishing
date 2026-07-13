-- Headless tests for the pure profile schema: defaults, deep/corruption-safe
-- reconcile, and the versioned migration engine. Run via Lune (see run.luau).

local ProfileSchema = require("../src/server/Data/ProfileSchema")

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

-- Defaults.
do
	local d = ProfileSchema.getDefaults()
	check("defaults schemaVersion is current", d.schemaVersion == ProfileSchema.CURRENT_VERSION)
	check("defaults coins is 0", d.coins == 0)
	check("defaults has LineLength at level 0", d.upgrades.LineLength == 0)
	check("defaults activeZone is sunny_shallows", d.activeZone == "sunny_shallows")
	check("defaults unlocks sunny_shallows", d.unlockedZones.sunny_shallows == true)
	check("defaults bestDepth is 0", d.bestDepth == 0)
	check("defaults tutorial not finished", d.tutorial.finished == false)
	check("defaults settings musicVolume is 1", d.settings.musicVolume == 1)

	-- Fresh, independent trees each call.
	local d2 = ProfileSchema.getDefaults()
	d.upgrades.LineLength = 9
	check("getDefaults returns independent trees", d2.upgrades.LineLength == 0)
end

-- Reconcile fills missing fields (top-level and nested).
do
	local partial = { coins = 50 }
	ProfileSchema.reconcile(partial)
	check("reconcile keeps existing coins", partial.coins == 50)
	check(
		"reconcile fills missing schemaVersion",
		partial.schemaVersion == ProfileSchema.CURRENT_VERSION
	)
	check("reconcile fills missing activeZone", partial.activeZone == "sunny_shallows")
	check("reconcile fills nested upgrades", partial.upgrades.LineLength == 0)
	check("reconcile fills nested settings", partial.settings.sfxVolume == 1)
end

-- Reconcile resets corrupt (wrong-typed) fields to defaults.
do
	local corrupt = {
		coins = "lots",
		upgrades = "broken",
		unlockedZones = 42,
		settings = { musicVolume = "loud" },
	}
	ProfileSchema.reconcile(corrupt)
	check("reconcile resets corrupt coins", corrupt.coins == 0)
	check(
		"reconcile resets corrupt upgrades to a table",
		type(corrupt.upgrades) == "table" and corrupt.upgrades.LineLength == 0
	)
	check("reconcile resets corrupt unlockedZones", type(corrupt.unlockedZones) == "table")
	check("reconcile resets corrupt nested setting", corrupt.settings.musicVolume == 1)
end

-- Reconcile preserves extra/dynamic entries and unknown keys.
do
	local rich = ProfileSchema.getDefaults()
	rich.upgrades.HookCapacity = 3
	rich.unlockedZones.kelp_forest = true
	rich.customField = "keep"
	ProfileSchema.reconcile(rich)
	check("reconcile preserves an extra upgrade entry", rich.upgrades.HookCapacity == 3)
	check("reconcile preserves an extra unlocked zone", rich.unlockedZones.kelp_forest == true)
	check("reconcile preserves the starter zone", rich.unlockedZones.sunny_shallows == true)
	check("reconcile preserves unknown keys", rich.customField == "keep")
end

-- Migration engine (injected synthetic migrations).
do
	local order = {}
	local migrations = {
		[1] = function(data)
			table.insert(order, 1)
			data.a = true
		end,
		[2] = function(data)
			table.insert(order, 2)
			data.b = true
		end,
	}
	local data = { schemaVersion = 1 }
	ProfileSchema.migrateWith(data, migrations, 3)
	check("migrate applies steps in order", order[1] == 1 and order[2] == 2)
	check("migrate ran step 1", data.a == true)
	check("migrate ran step 2", data.b == true)
	check("migrate stamps the target version", data.schemaVersion == 3)
end

do
	local order = {}
	local migrations = {
		[1] = function()
			table.insert(order, 1)
		end,
	}
	local data = { schemaVersion = 3 }
	ProfileSchema.migrateWith(data, migrations, 3)
	check("migrate is a no-op when already current", #order == 0 and data.schemaVersion == 3)
end

do
	local ran = false
	local migrations = {
		[0] = function()
			ran = true
		end,
	}
	local data = {}
	ProfileSchema.migrateWith(data, migrations, 1)
	check("migrate treats a missing version as 0", ran == true and data.schemaVersion == 1)
end

do
	local data = {}
	ProfileSchema.migrate(data)
	check("migrate() stamps CURRENT_VERSION", data.schemaVersion == ProfileSchema.CURRENT_VERSION)
end

-- Never downgrade a profile written by a newer build (rollback safety).
do
	local ran = {}
	local migrations = {
		[1] = function()
			table.insert(ran, 1)
		end,
	}
	local data = { schemaVersion = 5 }
	ProfileSchema.migrateWith(data, migrations, 3)
	check("migrate does not downgrade future-version data", data.schemaVersion == 5)
	check("migrate runs no steps on future-version data", #ran == 0)
end

return { passed = passed, failed = failed }
