--!strict
-- Player-facing text for hex tile effects: what a tile gives at a level, so
-- the upgrade sheet can show "Pet income +20% -> +30%". Lives in shared
-- Logic so it is unit tested against every tile in the config.

local Config = script.Parent.Parent:WaitForChild("Config")
local HexTree = require(Config:WaitForChild("HexTree"))

local Describe = {}

type Kind = "percent" | "seconds" | "count" | "hours" | "times" | "flag"

local STATS: { [string]: { label: string, kind: Kind } } = {
	petIncomeAdd = { label = "Pet income", kind = "percent" },
	collectorBonusPerSpecies = { label = "Income per species found", kind = "percent" },
	globalMultiplier = { label = "All income", kind = "times" },
	critChance = { label = "Critical income chance", kind = "percent" },
	critMultiplier = { label = "Critical payout", kind = "times" },
	luckAdd = { label = "Luck", kind = "percent" },
	luckMultiplier = { label = "Luck", kind = "times" },
	secretLuckAdd = { label = "Secret chance", kind = "percent" },
	secretLuckMultiplier = { label = "Secret chance", kind = "times" },
	luckyRollMultiplier = { label = "Luck on every 10th roll", kind = "times" },
	variantChanceAdd = { label = "Shiny and Rainbow chance", kind = "percent" },
	rollCooldownReduction = { label = "Roll cooldown", kind = "seconds" },
	rollCooldownFloor = { label = "Fastest roll cooldown", kind = "seconds" },
	eggDiscount = { label = "Roll price", kind = "percent" },
	hatchTimeReduction = { label = "Hatch time", kind = "percent" },
	hatchTimeMultiplier = { label = "Hatch time", kind = "times" },
	incubators = { label = "Incubators", kind = "count" },
	autoRoll = { label = "Auto Roll", kind = "flag" },
	autoHatch = { label = "Auto Hatch", kind = "flag" },
	padSlots = { label = "Farm pads", kind = "count" },
	petCapacity = { label = "Pet storage", kind = "count" },
	eggCapacity = { label = "Egg storage", kind = "count" },
	offlineRate = { label = "Offline earnings rate", kind = "percent" },
	offlineCapHours = { label = "Offline earnings cap", kind = "hours" },
}

-- Stats where a positive number is a reduction for the player.
local REDUCES = { rollCooldownReduction = true, eggDiscount = true, hatchTimeReduction = true }

local function trim(n: number, places: number): string
	local text = string.format(`%.{places}f`, n)
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Describe.known(stat: string): boolean
	return STATS[stat] ~= nil
end

function Describe.label(stat: string): string
	local info = STATS[stat]
	return if info then info.label else stat
end

-- The value an effect contributes at `level` (0 means not owned), as text.
function Describe.value(effect: HexTree.Effect, level: number): string
	local info = STATS[effect.stat]
	local kind: Kind = if info then info.kind else "count"
	if level <= 0 then
		-- what the stat is before any level: "0%", "x1", "Off" and so on
		if kind == "flag" then
			return "Off"
		elseif kind == "percent" then
			return "0%"
		elseif kind == "seconds" then
			return if effect.mode == "set" then "Default" else "0s"
		elseif kind == "hours" then
			return "0h"
		elseif kind == "times" then
			return "x1"
		end
		return "+0"
	end
	if effect.mode == "mul" then
		return "x" .. trim(effect.value ^ level, 2)
	end
	if effect.mode == "set" then
		if kind == "flag" then
			return "On"
		elseif kind == "times" then
			return "x" .. trim(effect.value, 2)
		elseif kind == "seconds" then
			return trim(effect.value, 2) .. "s"
		elseif kind == "percent" then
			return "+" .. trim(effect.value * 100, 1) .. "%"
		end
		return trim(effect.value, 2)
	end
	local total = effect.value * level
	local sign = if REDUCES[effect.stat] then "-" else "+"
	if kind == "percent" then
		return sign .. trim(total * 100, 1) .. "%"
	elseif kind == "seconds" then
		return sign .. trim(total, 2) .. "s"
	elseif kind == "hours" then
		return sign .. trim(total, 1) .. "h"
	elseif kind == "times" then
		return sign .. trim(total, 2) .. "x"
	end
	return sign .. trim(total, 0)
end

export type Line = { label: string, now: string, next: string? }

-- One line per effect: its label, value now, and value after the next level
-- (nil when the tile is maxed).
function Describe.tile(tileId: string, level: number): { Line }
	local tile = HexTree.byId[tileId]
	assert(tile ~= nil, `unknown tile {tileId}`)
	local lines = {}
	for _, effect in tile.effects do
		table.insert(lines, {
			label = Describe.label(effect.stat),
			now = Describe.value(effect, level),
			next = if level < tile.maxLevel then Describe.value(effect, level + 1) else nil,
		})
	end
	return lines
end

return Describe
