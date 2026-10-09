local Validate = require("../src/shared/Validate")
local T = require("./TestKit")

return {
	["String accepts a short string"] = function()
		T.truthy(Validate.String(8)("Poseidon"))
	end,
	["String rejects empty, long, non-string and invalid UTF-8"] = function()
		local check = Validate.String(8)
		T.falsy(check(""))
		T.falsy(check("Poseidon1"))
		T.falsy(check(5))
		T.falsy(check({}))
		T.falsy(check(nil))
		T.falsy(check("\255\254"))
	end,
	["Integer rejects NaN, infinity, fractions and out of range"] = function()
		local check = Validate.Integer(0, 100)
		T.truthy(check(0))
		T.truthy(check(100))
		T.falsy(check(0 / 0))
		T.falsy(check(math.huge))
		T.falsy(check(-math.huge))
		T.falsy(check(1.5))
		T.falsy(check(-1))
		T.falsy(check(101))
		T.falsy(check("5"))
	end,
	["OneOf accepts only listed strings"] = function()
		local check = Validate.OneOf({ "a", "b" })
		T.truthy(check("a"))
		T.falsy(check("c"))
		T.falsy(check(1))
	end,
	["Args requires the exact argument count"] = function()
		local checks = { Validate.String(8) }
		T.truthy(Validate.Args(checks, "x"))
		T.falsy(Validate.Args(checks))
		T.falsy(Validate.Args(checks, "x", "extra"))
		T.falsy(Validate.Args(checks, nil))
		T.truthy(Validate.Args({}))
		T.falsy(Validate.Args({}, "unexpected"))
	end,
}
