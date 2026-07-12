--!strict
-- Pure content validator.
--
-- Returns a list of human-readable problems (empty = valid): duplicate ids,
-- cross-reference failures (fish -> zone/rarity), and out-of-range numbers.
-- A leaf module with no requires (its input types are declared inline) so it and
-- the real content load headlessly under Lune; the registry (Content/init) runs
-- it at load and fails fast, and the content tests run it against the real data.

type Range = { min: number, max: number }

type FishRow = {
	id: string,
	displayName: string,
	zoneId: string,
	depthRange: Range,
	rarity: string,
	baseValue: number,
	sizeRange: Range,
	aquariumValue: number,
}

type ZoneRow = { id: string, displayName: string, maxDepth: number, unlockCost: number }

type UpgradeRow = {
	id: string,
	displayName: string,
	description: string,
	maxLevel: number,
	baseCost: number,
	effectBase: number,
	effectPerLevel: number,
}

type RarityRow = { id: string, weight: number, valueMultiplier: number }

export type Content = {
	fish: { FishRow },
	zones: { ZoneRow },
	upgrades: { UpgradeRow },
	rarities: { RarityRow },
}

local function validate(content: Content): { string }
	local issues: { string } = {}
	local function push(message: string)
		table.insert(issues, message)
	end

	local raritySet: { [string]: boolean } = {}
	for _, r in content.rarities do
		if raritySet[r.id] then
			push(("Duplicate rarity id '%s'."):format(r.id))
		end
		raritySet[r.id] = true
		if r.weight <= 0 then
			push(("Rarity '%s' weight must be > 0."):format(r.id))
		end
		if r.valueMultiplier <= 0 then
			push(("Rarity '%s' valueMultiplier must be > 0."):format(r.id))
		end
	end

	local zoneById: { [string]: ZoneRow } = {}
	for _, z in content.zones do
		if zoneById[z.id] then
			push(("Duplicate zone id '%s'."):format(z.id))
		end
		zoneById[z.id] = z
		if z.maxDepth < 0 or z.maxDepth > 1 then
			push(("Zone '%s' maxDepth must be in [0, 1]."):format(z.id))
		end
		if z.unlockCost < 0 then
			push(("Zone '%s' unlockCost must be >= 0."):format(z.id))
		end
	end

	local upgradeSet: { [string]: boolean } = {}
	for _, u in content.upgrades do
		if upgradeSet[u.id] then
			push(("Duplicate upgrade id '%s'."):format(u.id))
		end
		upgradeSet[u.id] = true
		if u.maxLevel < 1 then
			push(("Upgrade '%s' maxLevel must be >= 1."):format(u.id))
		end
		if u.baseCost <= 0 then
			push(("Upgrade '%s' baseCost must be > 0."):format(u.id))
		end
		if u.effectBase < 0 or u.effectBase > 1 then
			push(("Upgrade '%s' effectBase must be in [0, 1]."):format(u.id))
		end
		if u.effectPerLevel < 0 then
			push(("Upgrade '%s' effectPerLevel must be >= 0."):format(u.id))
		end
	end

	local fishSet: { [string]: boolean } = {}
	for _, f in content.fish do
		if fishSet[f.id] then
			push(("Duplicate fish id '%s'."):format(f.id))
		end
		fishSet[f.id] = true
		local zone = zoneById[f.zoneId]
		if not zone then
			push(("Fish '%s' references unknown zone '%s'."):format(f.id, f.zoneId))
		elseif f.depthRange.max > zone.maxDepth then
			push(
				("Fish '%s' depthRange.max (%.2f) exceeds zone '%s' maxDepth (%.2f) — uncatchable."):format(
					f.id,
					f.depthRange.max,
					f.zoneId,
					zone.maxDepth
				)
			)
		end
		if not raritySet[f.rarity] then
			push(("Fish '%s' references unknown rarity '%s'."):format(f.id, f.rarity))
		end
		local d = f.depthRange
		if d.min < 0 or d.min > 1 or d.max < 0 or d.max > 1 then
			push(("Fish '%s' depthRange must be within [0, 1]."):format(f.id))
		end
		if d.min > d.max then
			push(("Fish '%s' depthRange.min is greater than max."):format(f.id))
		end
		local s = f.sizeRange
		if s.min <= 0 then
			push(("Fish '%s' sizeRange.min must be > 0."):format(f.id))
		end
		if s.min > s.max then
			push(("Fish '%s' sizeRange.min is greater than max."):format(f.id))
		end
		if f.baseValue <= 0 then
			push(("Fish '%s' baseValue must be > 0."):format(f.id))
		end
		if f.aquariumValue < 0 then
			push(("Fish '%s' aquariumValue must be >= 0."):format(f.id))
		end
	end

	return issues
end

return validate
