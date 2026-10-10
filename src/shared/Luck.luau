--[[
	Luck: the luck multiplier and upgrade cost for a luck level.

	Takes the Economy config as an argument instead of requiring it, so it has
	no Roblox dependencies and is unit tested outside Studio.
]]

export type LuckConfig = {
	LuckPerLevel: number,
	LuckBaseCost: number,
	LuckCostGrowth: number,
	MaxLuckLevel: number,
}

local Luck = {}

function Luck.Multiplier(config: LuckConfig, level: number): number
	return 1 + config.LuckPerLevel * level
end

-- Cost to go from `level` to `level + 1`, or nil at the maximum level.
function Luck.UpgradeCost(config: LuckConfig, level: number): number?
	if level >= config.MaxLuckLevel then
		return nil
	end
	return math.floor(config.LuckBaseCost * config.LuckCostGrowth ^ level)
end

-- "x1.25" style text.
function Luck.Text(multiplier: number): string
	return `x{math.floor(multiplier * 100 + 0.5) / 100}`
end

return Luck
