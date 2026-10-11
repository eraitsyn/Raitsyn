local Test = require("../lib/Test")
local Game = require("../lib/Game")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Schema = Game.get("ServerScriptService.Server.Data.Schema")

describe("Schema", function()
	it("fills a brand-new profile from the template", function()
		local data = {}
		expect(Schema.migrate(data)).toBe("ok")
		expect(data.version).toBe(Schema.VERSION)
		expect(data.coins).toBe(0)
		expect(data.daily.streak).toBe(0)
		expect(type(data.pets)).toBe("table")
	end)

	it("adds missing nested keys without overwriting existing values", function()
		local data = { version = Schema.VERSION, coins = 123, daily = { streak = 4 } }
		Schema.migrate(data)
		expect(data.coins).toBe(123)
		expect(data.daily.streak).toBe(4)
		expect(data.daily.last).toBe(0)
		expect(data.settings.sfxVolume).toBe(1)
	end)

	it("refuses to touch data from a newer version", function()
		local data = { version = Schema.VERSION + 1, coins = 5 }
		expect(Schema.migrate(data)).toBe("future")
		expect(data.coins).toBe(5)
		expect(data.pets).toBe(nil)
	end)

	it("does not share tables between profiles", function()
		local a, b = {}, {}
		Schema.migrate(a)
		Schema.migrate(b)
		a.pets.x = true
		expect(b.pets.x).toBe(nil)
	end)

	it("repairs impossible states", function()
		local data = Schema.template()
		data.coins = -50
		data.pets.p1 = { s = "BarnChick", v = 0, t = 0, lk = false }
		data.pets.p2 = { s = "MossGoat", v = 0, t = 0, lk = false }
		data.placed["1"] = "p1"
		data.placed["2"] = "p1" -- same pet on two pads
		data.placed["3"] = "ghost" -- missing pet
		data.placed["99"] = "p2" -- pad out of range
		data.following = { "p1", "p2" } -- p1 is placed
		data.eggs.Common = 0
		local fixes = Schema.repair(data, 24, 3)
		expect(fixes).toBe(6)
		expect(data.coins).toBe(0)
		expect(data.placed["1"]).toBe("p1")
		expect(data.placed["2"]).toBe(nil)
		expect(data.placed["3"]).toBe(nil)
		expect(data.placed["99"]).toBe(nil)
		expect(#data.following).toBe(1)
		expect(data.following[1]).toBe("p2")
		expect(data.eggs.Common).toBe(nil)
	end)
end)

return nil
