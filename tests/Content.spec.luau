-- Headless tests for the Sunny Shallows content + the pure validator. Run via
-- Lune (see run.luau). Loads the REAL content (leaf data modules) and asserts it
-- validates, then feeds deliberately broken data to prove the validator catches it.

local Fish = require("../src/shared/Content/Fish")
local Zones = require("../src/shared/Content/Zones")
local Upgrades = require("../src/shared/Content/Upgrades")
local Rarity = require("../src/shared/Content/Rarity")
local validate = require("../src/shared/Content/validate")

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

local function content(overrides)
	local c = { fish = Fish, zones = Zones, upgrades = Upgrades, rarities = Rarity }
	if overrides then
		for key, value in overrides do
			c[key] = value
		end
	end
	return c
end

-- A shallow copy of `row` with one field overridden.
local function withField(row, key, value)
	local c = table.clone(row)
	c[key] = value
	return c
end

-- A shallow copy of `list` with one element replaced.
local function withRow(list, index, row)
	local c = table.clone(list)
	c[index] = row
	return c
end

-- A shallow copy of `list` with `row` appended.
local function appended(list, row)
	local c = table.clone(list)
	table.insert(c, row)
	return c
end

-- The real content validates cleanly.
do
	local issues = validate(content())
	check("Sunny Shallows content is valid", #issues == 0)
	for _, message in issues do
		print("    " .. message)
	end
end

check("5-8 fish are defined", #Fish >= 5 and #Fish <= 8)
check("Sunny Shallows zone is present", Zones[1].id == "sunny_shallows")
check("LineLength upgrade is present", Upgrades[1].id == "LineLength")

do
	local ok = true
	for _, f in Fish do
		if f.depthRange.min < 0 or f.depthRange.min > f.depthRange.max or f.depthRange.max > 1 then
			ok = false
		end
	end
	check("every fish depth is normalized and ordered", ok)
end

-- Broken data is rejected.
do
	local dup = { table.clone(Fish[1]), table.clone(Fish[1]) }
	check("duplicate fish id is caught", #validate(content({ fish = dup })) > 0)
end

do
	local orphan = table.clone(Fish[1])
	orphan.id = "orphan"
	orphan.zoneId = "atlantis"
	check("unknown zone reference is caught", #validate(content({ fish = { orphan } })) > 0)
end

do
	local weird = table.clone(Fish[1])
	weird.id = "weird"
	weird.rarity = "mythic"
	check("unknown rarity reference is caught", #validate(content({ fish = { weird } })) > 0)
end

do
	local deep = table.clone(Fish[1])
	deep.id = "deep"
	deep.depthRange = { min = 0.5, max = 1.5 }
	check("out-of-range depth is caught", #validate(content({ fish = { deep } })) > 0)
end

do
	local backwards = table.clone(Fish[1])
	backwards.id = "backwards"
	backwards.sizeRange = { min = 40, max = 10 }
	check("inverted size range is caught", #validate(content({ fish = { backwards } })) > 0)
end

-- Remaining fish rules.
check(
	"depthRange min > max is caught",
	#validate(
			content({ fish = { withField(Fish[1], "depthRange", { min = 0.6, max = 0.4 }) } })
		) > 0
)
check(
	"sizeRange.min <= 0 is caught",
	#validate(content({ fish = { withField(Fish[1], "sizeRange", { min = 0, max = 10 }) } })) > 0
)
check(
	"baseValue <= 0 is caught",
	#validate(content({ fish = { withField(Fish[1], "baseValue", 0) } })) > 0
)
check(
	"aquariumValue < 0 is caught",
	#validate(content({ fish = { withField(Fish[1], "aquariumValue", -1) } })) > 0
)
check(
	"depth beyond zone maxDepth is caught",
	#validate(
			content({ fish = { withField(Fish[1], "depthRange", { min = 0.9, max = 0.95 }) } })
		) > 0
)

-- Zone rules.
check("duplicate zone id is caught", #validate(content({ zones = { Zones[1], Zones[1] } })) > 0)
check(
	"zone maxDepth > 1 is caught",
	#validate(content({ zones = { withField(Zones[1], "maxDepth", 2) } })) > 0
)
check(
	"zone unlockCost < 0 is caught",
	#validate(content({ zones = { withField(Zones[1], "unlockCost", -5) } })) > 0
)

-- Rarity rules.
check(
	"duplicate rarity id is caught",
	#validate(content({ rarities = appended(Rarity, Rarity[1]) })) > 0
)
check(
	"rarity weight <= 0 is caught",
	#validate(content({ rarities = withRow(Rarity, 1, withField(Rarity[1], "weight", 0)) })) > 0
)
check(
	"rarity valueMultiplier <= 0 is caught",
	#validate(
			content({ rarities = withRow(Rarity, 1, withField(Rarity[1], "valueMultiplier", 0)) })
		) > 0
)

-- Upgrade rules.
check(
	"upgrade maxLevel < 1 is caught",
	#validate(content({ upgrades = { withField(Upgrades[1], "maxLevel", 0) } })) > 0
)
check(
	"upgrade baseCost <= 0 is caught",
	#validate(content({ upgrades = { withField(Upgrades[1], "baseCost", 0) } })) > 0
)
check(
	"upgrade effectBase out of [0,1] is caught",
	#validate(content({ upgrades = { withField(Upgrades[1], "effectBase", 2) } })) > 0
)
check(
	"upgrade effectPerLevel < 0 is caught",
	#validate(content({ upgrades = { withField(Upgrades[1], "effectPerLevel", -1) } })) > 0
)

return { passed = passed, failed = failed }
