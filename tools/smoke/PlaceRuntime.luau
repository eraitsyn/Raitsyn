--!strict
-- Runs ModuleScripts from a built place file under Lune, with real Roblox
-- instances from @lune/roblox. Unlike the unit-test loader, every property
-- write here is checked against Roblox's reflection database, so a typo in a
-- property name, a wrong value type or a bad enum fails loudly.
--
-- Lune does not implement every engine method, so the few the game's
-- builders use are filled in below with the same behaviour. Anything that
-- needs the live engine (physics, rendering, networking) is out of scope.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local PlaceRuntime = {}

-- Model:GetPivot / PivotTo, following the engine's rules: a model with a
-- PrimaryPart pivots about PrimaryPart.CFrame * PrimaryPart.PivotOffset,
-- otherwise about WorldPivot (kept in a side table, as Lune has no value for it).
local worldPivots: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function getPivot(model: any): any
	local primary = model.PrimaryPart
	if primary then
		return primary.CFrame * primary.PivotOffset
	end
	return worldPivots[model] or CFrame.new()
end

local function movePartsBy(model: any, delta: any)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

roblox.implementMethod("Model", "GetPivot", function(model)
	return getPivot(model)
end)
roblox.implementMethod("Model", "PivotTo", function(model, target)
	local delta = target * getPivot(model):Inverse()
	movePartsBy(model, delta)
	if not model.PrimaryPart then
		worldPivots[model] = target
	end
end)
roblox.implementProperty("Model", "WorldPivot", function(model)
	return worldPivots[model] or CFrame.new()
end, function(model, value)
	worldPivots[model] = value
end)
roblox.implementMethod("BasePart", "GetPivot", function(part)
	return part.CFrame
end)
-- Everything already exists in a built place, so WaitForChild never waits.
roblox.implementMethod("Instance", "WaitForChild", function(instance, name)
	local child = instance:FindFirstChild(name)
	assert(child, `WaitForChild: {name} is not a child of {instance:GetFullName()}`)
	return child
end)
roblox.implementMethod("Players", "GetUserThumbnailAsync", function()
	return "rbxthumb://type=AvatarHeadShot&id=1&w=180&h=180", true
end)

-- Lune's CFrame.lookAt faces the wrong way when looking straight along the Z
-- axis (the plots do exactly that), so the runtime swaps in the engine's
-- definition: LookVector points at the target, up stays as close to +Y as it can.
local function lookAt(at: any, target: any, up: any?): any
	local look = (target - at).Unit
	local worldUp = up or Vector3.yAxis
	local right = look:Cross(worldUp)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
	end
	right = right.Unit
	local up2 = right:Cross(look).Unit
	return CFrame.fromMatrix(at, right, up2, -look)
end
local FixedCFrame = setmetatable({ lookAt = lookAt }, { __index = CFrame })

-- Lune cannot derive BasePart.Position from CFrame (and will not let it be
-- overridden), so game code reads part.CFrame.Position instead.

-- Engine Random, with the methods the game uses.
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local state = math.floor(seed or os.clock() * 1e6) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, Random)
end
function Random:_next(): number
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min: number?, max: number?): number
	local a, b = min or 0, max or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(min: number, max: number): number
	return math.floor(min + (max - min + 1) * self:_next())
end

-- task.* runs deferred work immediately; delays are dropped.
local taskLib = {
	spawn = function(fn: any, ...: any)
		fn(...)
	end,
	defer = function(fn: any, ...: any)
		fn(...)
	end,
	delay = function() end,
	wait = function()
		return 0
	end,
}

export type Runtime = {
	game: any,
	require: (module: any) -> any,
}

function PlaceRuntime.load(placePath: string): Runtime
	local game = roblox.deserializePlace(fs.readFile(placePath))
	local cache: { [any]: any } = {}
	local loading: { [any]: boolean } = {}

	local function requireModule(module: any): any
		assert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "require expects a ModuleScript")
		if cache[module] ~= nil then
			return cache[module]
		end
		assert(not loading[module], `circular require of {module:GetFullName()}`)
		loading[module] = true
		-- luau.load does not consult __index for globals, so the environment
		-- gets every Roblox datatype copied in.
		local env: { [string]: any } = {}
		for key, value in roblox do
			env[key] = value
		end
		env.script = module
		env.require = requireModule
		env.game = game
		env.workspace = game:GetService("Workspace")
		env.Instance = Instance
		env.CFrame = FixedCFrame
		env.Random = Random
		env.task = taskLib
		env.warn = function(...)
			print("[warn]", ...)
		end
		local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = env :: any })
		local result = chunk()
		loading[module] = nil
		cache[module] = result
		return result
	end

	return { game = game, require = requireModule }
end

PlaceRuntime.Vector3 = Vector3
PlaceRuntime.CFrame = FixedCFrame

return PlaceRuntime
