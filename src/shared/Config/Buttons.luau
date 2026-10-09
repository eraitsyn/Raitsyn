--[[
	Every purchasable button, keyed by a stable id that is saved in player data.

	price    whole number of cash
	item     name of a Model in ServerStorage.Items to clone into the plot
	requires button ids that must be owned before this button appears

	Renaming an id drops it from existing saves, so add new ids instead.
	New players start with 0 cash, so the first dropper must be free.
]]

return {
	Conveyor1 = { label = "Conveyor", price = 0, item = "Conveyor1", requires = {} },
	Dropper1 = { label = "Dropper", price = 0, item = "Dropper1", requires = { "Conveyor1" } },
	Dropper2 = { label = "Fast Dropper", price = 100, item = "Dropper2", requires = { "Dropper1" } },
	Upgrader1 = { label = "Upgrader x2", price = 500, item = "Upgrader1", requires = { "Dropper2" } },
}
