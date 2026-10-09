local Rolls = require("../src/shared/Rolls")
local T = require("./TestKit")

local RARITIES = {
	{ name = "Common", weight = 75 },
	{ name = "Rare", weight = 25 },
	{ name = "Secret", weight = 0 },
}

local function sequence(values: { number })
	local index = 0
	return function()
		index += 1
		return values[index]
	end
end

return {
	["PickRarity follows the weights"] = function()
		T.equal(Rolls.PickRarity(RARITIES, sequence({ 0 })), "Common")
		T.equal(Rolls.PickRarity(RARITIES, sequence({ 0.749 })), "Common")
		T.equal(Rolls.PickRarity(RARITIES, sequence({ 0.75 })), "Rare")
		T.equal(Rolls.PickRarity(RARITIES, sequence({ 0.999999 })), "Rare")
	end,
	["PickRarity never returns a zero-weight rarity inside the range"] = function()
		for step = 0, 99 do
			T.truthy(Rolls.PickRarity(RARITIES, sequence({ step / 100 })) ~= "Secret")
		end
	end,
	["GroupByRarity sorts ids"] = function()
		local groups = Rolls.GroupByRarity({
			Zed = { rarity = "Common" },
			Abe = { rarity = "Common" },
			Mid = { rarity = "Rare" },
		})
		T.equal(groups.Common[1], "Abe")
		T.equal(groups.Common[2], "Zed")
		T.equal(groups.Rare[1], "Mid")
	end,
	["RollGod skips rarities with no gods"] = function()
		local groups = { Rare = { "OnlyRare" } }
		T.equal(Rolls.RollGod(RARITIES, groups, sequence({ 0, 0 })), "OnlyRare")
	end,
	["RollGod picks within the rolled rarity, including the last id"] = function()
		local groups = { Common = { "A", "B" }, Rare = { "C" } }
		T.equal(Rolls.RollGod(RARITIES, groups, sequence({ 0.1, 0 })), "A")
		T.equal(Rolls.RollGod(RARITIES, groups, sequence({ 0.1, 0.99 })), "B")
		T.equal(Rolls.RollGod(RARITIES, groups, sequence({ 0.9, 0.5 })), "C")
	end,
	["shipped roster has every rarity filled and sensible numbers"] = function()
		local config = require("../src/shared/Config/Gods")
		local groups = Rolls.GroupByRarity(config.Gods)
		for _, rarity in config.Rarities do
			T.truthy(groups[rarity.name] and #groups[rarity.name] > 0, `no gods for {rarity.name}`)
		end
		for id, god in config.Gods do
			T.truthy(god.price > 0 and god.price % 1 == 0, `{id} price`)
			T.truthy(god.income > 0 and god.income % 1 == 0, `{id} income`)
		end
	end,
}
