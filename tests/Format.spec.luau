local Format = require("../src/shared/Format")
local T = require("./TestKit")

return {
	["small numbers stay exact"] = function()
		T.equal(Format.Short(0), "0")
		T.equal(Format.Short(50), "50")
		T.equal(Format.Short(999), "999")
	end,
	["large numbers get a suffix and trimmed decimals"] = function()
		T.equal(Format.Short(1000), "1K")
		T.equal(Format.Short(1250), "1.25K")
		T.equal(Format.Short(1500), "1.5K")
		T.equal(Format.Short(1150), "1.15K")
		T.equal(Format.Short(3400000), "3.4M")
		T.equal(Format.Short(2500000000), "2.5B")
	end,
	["rounds down so it never shows more than you have"] = function()
		T.equal(Format.Short(1999), "1.99K")
		T.equal(Format.Short(999999), "999.99K")
	end,
	["multiplier and duration text"] = function()
		T.equal(Format.Multiplier(1.25), "x1.25")
		T.equal(Format.Multiplier(1), "x1")
		T.equal(Format.Duration(45), "45s")
		T.equal(Format.Duration(125), "2:05")
		T.equal(Format.Duration(4800), "1h 20m")
		T.equal(Format.Duration(-3), "0s")
	end,
	["cash adds a dollar sign"] = function()
		T.equal(Format.Cash(2500), "$2.5K")
	end,
}
