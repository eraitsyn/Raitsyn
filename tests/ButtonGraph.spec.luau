local ButtonGraph = require("../src/shared/ButtonGraph")
local Buttons = require("../src/shared/Config/Buttons")
local T = require("./TestKit")

local function button(requires: { string }, price: number?)
	return { label = "x", price = price or 10, item = "Item", requires = requires }
end

return {
	["shipped config is valid"] = function()
		local ok, message = ButtonGraph.Check(Buttons)
		T.truthy(ok, message)
	end,
	["rejects unknown prerequisites"] = function()
		local ok = ButtonGraph.Check({ A = button({ "Missing" }) })
		T.falsy(ok)
	end,
	["rejects cycles"] = function()
		local ok, message = ButtonGraph.Check({ A = button({ "B" }), B = button({ "A" }) })
		T.falsy(ok)
		T.truthy(message and string.find(message, "cycle"), message)
	end,
	["rejects negative and fractional prices"] = function()
		T.falsy(ButtonGraph.Check({ A = button({}, -1) }))
		T.falsy(ButtonGraph.Check({ A = button({}, 1.5) }))
	end,
	["orders every button after its prerequisites"] = function()
		local buttons = { C = button({ "B" }), B = button({ "A" }), A = button({}), D = button({ "A", "C" }) }
		local order = ButtonGraph.Order(buttons)
		T.equal(#order, 4)
		local position = {}
		for index, id in order do
			position[id] = index
		end
		for id, config in buttons do
			for _, required in config.requires do
				T.truthy(position[required] < position[id], `{required} should come before {id}`)
			end
		end
	end,
	["IsUnlocked needs every prerequisite"] = function()
		local buttons = { A = button({}), B = button({ "A" }), C = button({ "A", "B" }) }
		T.truthy(ButtonGraph.IsUnlocked(buttons, "A", {}))
		T.falsy(ButtonGraph.IsUnlocked(buttons, "B", {}))
		T.truthy(ButtonGraph.IsUnlocked(buttons, "B", { A = true }))
		T.falsy(ButtonGraph.IsUnlocked(buttons, "C", { A = true }))
		T.falsy(ButtonGraph.IsUnlocked(buttons, "Nope", { A = true }))
	end,
}
