--[[
	Dropper and upgrader behaviour, keyed by item name (see Config/Buttons).

	A dropper item needs a part named DropOrigin; drops spawn just below it.
	An upgrader item needs a part named UpgradeZone; drops touching it are multiplied once.
]]

return {
	Droppers = {
		Dropper1 = { interval = 2.0, value = 5 },
		Dropper2 = { interval = 1.5, value = 12 },
	},
	Upgraders = {
		Upgrader1 = { multiplier = 2 },
	},
}
