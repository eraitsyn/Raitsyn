--!strict
-- World effects drawn on each client:
--  * Followers: up to three pets trail every player. The server publishes
--    which ones (a "Following" attribute on the Player); each client builds
--    and moves its own copies, so following costs the server nothing.
--  * Rainbow pets cycle their body colour, on farms and as followers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))
local Pets = require(Shared:WaitForChild("Config"):WaitForChild("Pets"))

local Effects = {}

local DRAW_DISTANCE = 220
-- Slots behind the player, in the character's local space (+Z is behind).
local SLOTS = { Vector3.new(-3.5, 0, 4), Vector3.new(3.5, 0, 4), Vector3.new(0, 0, 7.5) }
local RAINBOW_HZ = 15

type Follower = { model: Model, cframe: CFrame?, phase: number }
type Trail = { key: string, followers: { Follower } }

local folder = Instance.new("Folder")
folder.Name = "ClientFollowers"
folder.Parent = workspace

local trails: { [Player]: Trail } = {}

--------------------------------------------------------------------------------
-- Rainbow

local rainbowParts: { [Model]: { BasePart } } = {}

local function trackRainbow(model: Model)
	if model:GetAttribute("Variant") ~= "Rainbow" or rainbowParts[model] then
		return
	end
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Paint") == "Body" then
			table.insert(parts, part)
		end
	end
	rainbowParts[model] = parts
end

local function watchForRainbows(root: Instance)
	for _, child in root:GetDescendants() do
		if child:IsA("Model") then
			trackRainbow(child)
		end
	end
	root.DescendantAdded:Connect(function(child)
		if child:IsA("Model") then
			-- attributes and parts replicate with the model; wait a frame so
			-- the whole model is present
			task.defer(trackRainbow, child)
		end
	end)
end

local function paintRainbows(now: number)
	for model, parts in rainbowParts do
		if model.Parent == nil then
			rainbowParts[model] = nil
			continue
		end
		local hue = (now * 0.25) % 1
		for i, part in parts do
			part.Color = Color3.fromHSV((hue + i * 0.08) % 1, 0.65, 1)
		end
	end
end

--------------------------------------------------------------------------------
-- Followers

local function clearTrail(player: Player)
	local trail = trails[player]
	if trail then
		for _, follower in trail.followers do
			follower.model:Destroy()
		end
		trails[player] = nil
	end
end

-- Parses "Species:variantOrder,..." defensively: anything unknown is skipped.
local function parse(value: any): { { species: string, variant: string } }
	local list = {}
	if type(value) ~= "string" then
		return list
	end
	for entry in string.gmatch(value, "[^,]+") do
		local species, order = string.match(entry, "^(%w+):(%d)$")
		local variant = order and Pets.variants[(tonumber(order) or 0) + 1]
		if species and Pets.byId[species] and variant and #list < #SLOTS then
			table.insert(list, { species = species, variant = variant.id })
		end
	end
	return list
end

local function rebuild(player: Player)
	local value = player:GetAttribute("Following")
	local key = if type(value) == "string" then value else ""
	local existing = trails[player]
	if existing and existing.key == key then
		return
	end
	clearTrail(player)
	local followers = {}
	for i, entry in parse(value) do
		local model = PetModel.build(entry.species, entry.variant)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		model.Name = `{player.Name}_{i}`
		model.Parent = folder
		trackRainbow(model)
		table.insert(followers, { model = model, cframe = nil, phase = i * 1.7 })
	end
	trails[player] = { key = key, followers = followers }
end

local function watchPlayer(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("Following"):Connect(function()
		rebuild(player)
	end)
end

local function moveFollowers(dt: number, now: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local blend = 1 - math.exp(-dt * 7)
	for player, trail in trails do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visible = root ~= nil and humanoid ~= nil and (root.Position - eye).Magnitude < DRAW_DISTANCE
		for _, follower in trail.followers do
			if not visible then
				-- park out of sight; snap back into place when visible again
				if follower.cframe ~= nil then
					follower.model:PivotTo(CFrame.new(0, -500, 0))
					follower.cframe = nil
				end
			end
		end
		if not visible or root == nil or humanoid == nil then
			continue
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		end
		local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
		local base = CFrame.lookAt(Vector3.new(root.Position.X, feetY, root.Position.Z), root.Position + look * 100)
		for i, follower in trail.followers do
			local slot = SLOTS[i]
			local target = base * CFrame.new(slot)
			local previous = follower.cframe
			local current: CFrame = if previous then previous:Lerp(target, blend) else target
			follower.cframe = current
			local bob = math.abs(math.sin(now * 5 + follower.phase)) * 0.35
			follower.model:PivotTo(current + Vector3.new(0, bob, 0))
		end
	end
end

--------------------------------------------------------------------------------

function Effects.start()
	local world = workspace:WaitForChild("World")
	watchForRainbows(world:WaitForChild("Plots"))

	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clearTrail)

	local sinceRainbow = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		moveFollowers(dt, now)
		sinceRainbow += dt
		if sinceRainbow >= 1 / RAINBOW_HZ then
			sinceRainbow = 0
			paintRainbows(now)
		end
	end)
end

return Effects
