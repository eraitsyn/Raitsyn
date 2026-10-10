--[[
	Upgrades: the value and cost of an upgrade at a level.

	Takes the upgrade's definition from Config/Economy as an argument, so it has
	no Roblox dependencies and is unit tested outside Studio.
]]

export type Definition = {
	id: string,
	start: number,
	perLevel: number,
	maxLevel: number,
	baseCost: number,
	growth: number,
}

local Upgrades = {}

-- The upgrade's value at `level`: a count (slots) or a multiplier (speed, luck).
function Upgrades.Value(definition: Definition, level: number): number
	return definition.start + definition.perLevel * level
end

-- Cost to go from `level` to `level + 1`, or nil at the maximum level.
function Upgrades.Cost(definition: Definition, level: number): number?
	if level >= definition.maxLevel then
		return nil
	end
	return math.floor(definition.baseCost * definition.growth ^ level)
end

-- The definition with this id from a list of definitions.
function Upgrades.Find(definitions: { Definition }, id: string): Definition?
	for _, definition in definitions do
		if definition.id == id then
			return definition
		end
	end
	return nil
end

return Upgrades
