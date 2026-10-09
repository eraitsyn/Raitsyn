--[[
	ButtonGraph: pure helpers over the button config's dependency graph.

	No Roblox dependencies, so it is unit tested outside Studio.
]]

export type ButtonConfig = {
	label: string,
	price: number,
	item: string,
	requires: { string },
}

export type Buttons = { [string]: ButtonConfig }

local ButtonGraph = {}

-- Returns true, or false and a message naming the first problem found.
function ButtonGraph.Check(buttons: Buttons): (boolean, string?)
	for id, button in buttons do
		if type(button.price) ~= "number" or button.price < 0 or button.price % 1 ~= 0 then
			return false, `{id}: price must be a whole number >= 0`
		end
		if type(button.item) ~= "string" or button.item == "" then
			return false, `{id}: item must be a non-empty string`
		end
		for _, required in button.requires do
			if buttons[required] == nil then
				return false, `{id}: requires unknown button {required}`
			end
		end
	end

	-- Depth-first search for cycles: 1 = visiting, 2 = done.
	local marks: { [string]: number } = {}
	local function visit(id: string): string?
		if marks[id] == 2 then
			return nil
		elseif marks[id] == 1 then
			return id
		end
		marks[id] = 1
		for _, required in buttons[id].requires do
			local cycleAt = visit(required)
			if cycleAt then
				return cycleAt
			end
		end
		marks[id] = 2
		return nil
	end
	for id in buttons do
		local cycleAt = visit(id)
		if cycleAt then
			return false, `dependency cycle through {cycleAt}`
		end
	end

	return true, nil
end

-- Button ids ordered so every button comes after the buttons it requires.
-- Ties are broken by id so the order is the same on every server.
function ButtonGraph.Order(buttons: Buttons): { string }
	local ids = {}
	for id in buttons do
		table.insert(ids, id)
	end
	table.sort(ids)

	local order = {}
	local placed: { [string]: boolean } = {}
	local function place(id: string)
		if placed[id] then
			return
		end
		placed[id] = true
		local requires = table.clone(buttons[id].requires)
		table.sort(requires)
		for _, required in requires do
			place(required)
		end
		table.insert(order, id)
	end
	for _, id in ids do
		place(id)
	end
	return order
end

-- True when every button this one requires has been purchased.
function ButtonGraph.IsUnlocked(buttons: Buttons, id: string, purchased: { [string]: boolean }): boolean
	local button = buttons[id]
	if button == nil then
		return false
	end
	for _, required in button.requires do
		if not purchased[required] then
			return false
		end
	end
	return true
end

return ButtonGraph
