--!strict
-- Rolling options. Each tier costs more and multiplies luck. Tiers unlock by
-- lifetime coins earned (which survives rebirth) and optionally a rebirth count.

export type RollTier = {
	id: string,
	name: string,
	order: number,
	price: number,
	luck: number,
	unlockLifetimeCoins: number,
	unlockRebirths: number,
}

local list: { RollTier } = {
	{ id = "Basic", name = "Basic Roll", order = 1, price = 50, luck = 1, unlockLifetimeCoins = 0, unlockRebirths = 0 },
	{
		id = "Silver",
		name = "Silver Roll",
		order = 2,
		price = 1_500,
		luck = 2.5,
		unlockLifetimeCoins = 50_000,
		unlockRebirths = 0,
	},
	{
		id = "Gold",
		name = "Gold Roll",
		order = 3,
		price = 50_000,
		luck = 6,
		unlockLifetimeCoins = 2_500_000,
		unlockRebirths = 0,
	},
	{
		id = "Diamond",
		name = "Diamond Roll",
		order = 4,
		price = 1_500_000,
		luck = 15,
		unlockLifetimeCoins = 150_000_000,
		unlockRebirths = 0,
	},
	{
		id = "Cosmic",
		name = "Cosmic Roll",
		order = 5,
		price = 60_000_000,
		luck = 40,
		unlockLifetimeCoins = 5_000_000_000,
		unlockRebirths = 1,
	},
}

local byId: { [string]: RollTier } = {}
for _, tier in list do
	byId[tier.id] = tier
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
