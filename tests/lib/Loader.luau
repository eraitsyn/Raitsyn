--!strict
-- A tiny stand-in for Roblox's module system so the game's ModuleScripts can
-- run unchanged under Lune. It mirrors default.project.json: each source
-- folder becomes a fake Instance tree, `script` points at the module's own
-- node, and `require(node)` loads the matching .luau file once.
--
-- Only what pure modules need is supported: .Name, .Parent, child access by
-- name, FindFirstChild, WaitForChild, GetChildren, and game:GetService for the
-- mapped services. Roblox datatypes (Color3, Vector3, ...) come from
-- @lune/roblox.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

export type Node = {
	Name: string,
	Parent: Node?,
	path: string?, -- .luau file backing this node, if it is a module
	children: { [string]: Node },
}

local Loader = {}

local nodeMeta = {}
local cache: { [Node]: any } = {}
local loading: { [Node]: boolean } = {}

local function newNode(name: string, parent: Node?, path: string?): Node
	local node = { Name = name, Parent = parent, path = path, children = {} }
	if parent then
		parent.children[name] = node
	end
	return setmetatable(node, nodeMeta) :: any
end

nodeMeta.__index = function(self: Node, key: string): any
	local method = (nodeMeta :: any).methods[key]
	if method then
		return method
	end
	local child = rawget(self :: any, "children")[key]
	if child then
		return child
	end
	error(`{key} is not a valid member of {rawget(self :: any, "Name")}`, 2)
end
nodeMeta.__tostring = function(self: Node)
	return rawget(self :: any, "Name")
end
(nodeMeta :: any).methods = {
	FindFirstChild = function(self: Node, name: string): Node?
		return rawget(self :: any, "children")[name]
	end,
	WaitForChild = function(self: Node, name: string): Node
		local child = rawget(self :: any, "children")[name]
		assert(child, `WaitForChild: {name} not found under {rawget(self :: any, "Name")}`)
		return child
	end,
	GetChildren = function(self: Node): { Node }
		local list = {}
		for _, child in rawget(self :: any, "children") do
			table.insert(list, child)
		end
		return list
	end,
	IsA = function(_self: Node, className: string): boolean
		return className == "Instance" or className == "ModuleScript"
	end,
}

-- Builds nodes for a directory, following Rojo's conventions:
-- Foo.luau -> module Foo; Foo/ -> folder Foo; Foo/init.luau -> module Foo.
local function mount(dir: string, node: Node)
	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			local initPath = `{full}/init.luau`
			local child = newNode(entry, node, if fs.isFile(initPath) then initPath else nil)
			mount(full, child)
		elseif string.match(entry, "%.luau$") and entry ~= "init.luau" then
			local name = string.gsub(entry, "%.server%.luau$", "")
			name = string.gsub(name, "%.client%.luau$", "")
			name = string.gsub(name, "%.luau$", "")
			newNode(name, node, full)
		end
	end
end

local services: { [string]: Node } = {}
local game = newNode("game", nil, nil)

-- mapping: service name -> { [child name] = source dir }
function Loader.init(root: string, mapping: { [string]: { [string]: string } })
	for serviceName, folders in mapping do
		local service = services[serviceName] or newNode(serviceName, game, nil)
		services[serviceName] = service
		for childName, dir in folders do
			local child = newNode(childName, service, nil)
			mount(`{root}/{dir}`, child)
		end
	end
end

local function requireNode(node: any): any
	if type(node) ~= "table" or getmetatable(node) ~= nodeMeta then
		error("require expects a module node", 2)
	end
	if cache[node] ~= nil then
		return cache[node]
	end
	local path = rawget(node, "path")
	assert(path, `{rawget(node, "Name")} is not a module`)
	assert(not loading[node], `circular require of {path}`)
	loading[node] = true
	local source = fs.readFile(path)
	local env = setmetatable({
		script = node,
		require = requireNode,
		game = game,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
	}, { __index = _G :: any })
	local chunk = luau.load(source, { debugName = path, environment = env :: any })
	local result = chunk()
	loading[node] = nil
	cache[node] = result
	return result
end
(nodeMeta :: any).methods.GetService = function(_self: Node, name: string): Node
	local service = services[name]
	assert(service, `service {name} is not mapped in the test loader`)
	return service
end

Loader.require = requireNode
Loader.game = game

-- Convenience: require by dotted path, e.g. "ReplicatedStorage.Shared.Logic.Odds".
function Loader.get(path: string): any
	local node: any = nil
	for part in string.gmatch(path, "[^%.]+") do
		if node == nil then
			node = services[part]
			assert(node, `unknown service {part}`)
		else
			node = node[part]
		end
	end
	return requireNode(node)
end

return Loader
