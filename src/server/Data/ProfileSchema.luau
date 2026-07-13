--!strict
-- Pure profile schema: defaults, deep (corruption-safe) reconcile, and versioned
-- migrations.
--
-- A LEAF module (no requires) so it loads headlessly under Lune for tests. The
-- starter content ids below are the profile's STARTING STATE; the Content
-- registry owns the catalog — keep the two in sync (a later stage can assert it).
-- ProfileStore itself owns session metadata (Profile.Session, UserIds,
-- SessionLoadCount, FirstSessionTime); this schema is only the saved Data table.

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 1

export type AquariumEntry = {
	bestSize: number,
	discoveredAt: number,
}

export type ProfileData = {
	schemaVersion: number,
	coins: number,
	upgrades: { [string]: number }, -- upgradeId -> level (includes LineLength)
	activeZone: string,
	unlockedZones: { [string]: boolean }, -- set of unlocked zone ids
	discoveredFish: { [string]: boolean }, -- set of discovered fish ids
	aquarium: { [string]: AquariumEntry }, -- speciesId -> best specimen
	bestDepth: number, -- best normalized depth reached (0..1)
	lastLogoutAt: number, -- os.time() of last release (offline earnings, later)
	tutorial: { finished: boolean, steps: { [string]: boolean } },
	settings: { musicVolume: number, sfxVolume: number },
}

local STARTER_ZONE = "sunny_shallows"
local STARTER_UPGRADE = "LineLength"

-- Default profile for a brand-new player. All literals, so every call returns a
-- fresh tree with no shared nested tables — safe to use as the ProfileStore
-- template and as the reconcile reference.
function ProfileSchema.getDefaults(): ProfileData
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		coins = 0,
		upgrades = { [STARTER_UPGRADE] = 0 },
		activeZone = STARTER_ZONE,
		unlockedZones = { [STARTER_ZONE] = true },
		discoveredFish = {},
		aquarium = {},
		bestDepth = 0,
		lastLogoutAt = 0,
		tutorial = { finished = false, steps = {} },
		settings = { musicVolume = 1, sfxVolume = 1 },
	}
end

-- Profile data is always acyclic and metatable-free (DataStore enforces this at
-- save time), so a plain recursive copy is safe — no cycle guard needed.
local function deepCopy(source: { [any]: any }): { [any]: any }
	local copy = {}
	for key, value in source do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Fill missing fields from `defaults` and reset any field whose type no longer
-- matches its default (corruption-safe). Nested record tables recurse; unknown
-- extra keys are preserved (forward compatibility). Open-ended maps (e.g.
-- discoveredFish, aquarium) are ensured to be tables, but their individual
-- entries are not validated per-entry here. Mutates `data` in place.
local function reconcileInto(data: { [string]: any }, defaults: { [string]: any })
	for key, defaultValue in defaults do
		local current = data[key]
		if type(defaultValue) == "table" then
			if type(current) ~= "table" then
				data[key] = deepCopy(defaultValue)
			else
				reconcileInto(current, defaultValue)
			end
		elseif type(current) ~= type(defaultValue) then
			data[key] = defaultValue
		end
	end
end

-- Reconcile a (possibly missing/corrupt) data table against the defaults.
function ProfileSchema.reconcile(data: { [string]: any }): { [string]: any }
	reconcileInto(data, ProfileSchema.getDefaults() :: { [string]: any })
	return data
end

type Migration = (data: { [string]: any }) -> ()

-- Ordered migrations. MIGRATIONS[v] upgrades data FROM schemaVersion v TO v + 1.
-- Empty for now (v1 is the first schema); each future schema change adds a step.
local MIGRATIONS: { [number]: Migration } = {}

-- Apply migration steps in order up to `targetVersion`, then stamp the version.
-- Exposed (with injectable `migrations`) so the migration ENGINE is unit-tested
-- independently of whatever concrete migrations exist. Mutates `data` in place.
function ProfileSchema.migrateWith(
	data: { [string]: any },
	migrations: { [number]: Migration },
	targetVersion: number
): { [string]: any }
	local version = tonumber(data.schemaVersion) or 0
	while version < targetVersion do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	-- Stamp the final version (max of the original and target) so data written by
	-- a NEWER build than the running server is never downgraded — which would
	-- otherwise re-run migrations and corrupt it after a rollback.
	data.schemaVersion = version
	return data
end

-- Migrate a data table up to the current schema version.
function ProfileSchema.migrate(data: { [string]: any }): { [string]: any }
	return ProfileSchema.migrateWith(data, MIGRATIONS, ProfileSchema.CURRENT_VERSION)
end

return ProfileSchema
