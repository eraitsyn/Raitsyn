--[[
	Janitor: collects cleanup work so one Destroy() call tears everything down.

	Accepts RBXScriptConnections, Instances, threads, functions, and tables with a
	Destroy or Disconnect method. Cleanup runs in reverse order of Add, so later
	things that depend on earlier ones go first.
]]

local Janitor = {}
Janitor.__index = Janitor

export type Janitor = typeof(setmetatable({} :: { _items: { any } }, Janitor))

function Janitor.new(): Janitor
	return setmetatable({ _items = {} }, Janitor)
end

function Janitor.Add<T>(self: Janitor, item: T): T
	table.insert(self._items, item)
	return item
end

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			task.cancel(item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

-- Runs every cleanup now and leaves the janitor empty and reusable.
function Janitor.Cleanup(self: Janitor)
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		local ok, err = pcall(cleanItem, items[index])
		if not ok then
			warn(`[Janitor] cleanup failed: {err}`)
		end
	end
end

Janitor.Destroy = Janitor.Cleanup

return Janitor
