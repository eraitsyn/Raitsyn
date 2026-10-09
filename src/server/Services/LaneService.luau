--[[
	LaneService: the conveyor of random gods everyone can buy from.

	Rolls happen on the server with Random.new(), so a client cannot influence
	which god appears. The first player to buy a god gets it; it then leaves the lane.

	Expected layout: workspace.Lane with parts LaneStart and LaneEnd. Gods walk
	along the line between them, standing on LaneStart's top surface height.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GodConfig = require(ReplicatedStorage.Shared.Config.Gods)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local GodFactory = require(script.Parent.Parent.GodFactory)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local GodService = require(script.Parent.GodService)
local PlotService = require(script.Parent.PlotService)

type Walker = { godId: string, model: Model, travelled: number }

local random = Random.new()
local groups = Rolls.GroupByRarity(GodConfig.Gods)
local walkers: { Walker } = {}

local LaneService = {}

local function removeWalker(walker: Walker)
	local index = table.find(walkers, walker)
	if index then
		table.remove(walkers, index)
	end
	walker.model:Destroy()
end

local function tryBuy(player: Player, walker: Walker)
	if not Gate.AllowPrompt(player) or table.find(walkers, walker) == nil then
		return
	end
	local state = PlotService.Get(player)
	if state == nil or not Reach.Within(player, walker.model:GetPivot().Position, Economy.ReachDistance) then
		return
	end
	local god = GodConfig.Gods[walker.godId]
	if DataSchema.FreeSlot(state.data, Economy.SlotsPerBase) == nil then
		Gate.Notify(player, "BaseFull", walker.godId)
		return
	end
	if not CurrencyService.TrySpend(player, god.price) then
		Gate.Notify(player, "TooPoor", walker.godId)
		return
	end
	-- Nothing above yields, so no other buyer can take this god in between.
	removeWalker(walker)
	GodService.Give(state, walker.godId)
	Gate.Notify(player, "Bought", walker.godId)
end

local function spawnWalker(folder: Instance)
	if #walkers >= Economy.MaxGodsOnLane then
		return
	end
	local godId = Rolls.RollGod(GodConfig.Rarities, groups, function()
		return random:NextNumber()
	end)
	local god = GodConfig.Gods[godId]
	local model = GodFactory.Build(godId)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = `{god.name} (${god.price})`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Economy.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Buy")
	prompt.Parent = model.PrimaryPart

	local walker: Walker = { godId = godId, model = model, travelled = 0 }
	prompt.Triggered:Connect(function(player: Player)
		tryBuy(player, walker)
	end)
	model.Parent = folder
	table.insert(walkers, walker)
end

function LaneService.Init()
	local lane = workspace:WaitForChild("Lane")
	local laneStart = lane:WaitForChild("LaneStart") :: BasePart
	local laneEnd = lane:WaitForChild("LaneEnd") :: BasePart

	local height = laneStart.Position.Y + laneStart.Size.Y / 2
	local from = Vector3.new(laneStart.Position.X, height, laneStart.Position.Z)
	local to = Vector3.new(laneEnd.Position.X, height, laneEnd.Position.Z)
	local length = (to - from).Magnitude
	local direction = (to - from).Unit

	local folder = Instance.new("Folder")
	folder.Name = "LaneGods"
	folder.Parent = workspace

	local nextSpawn = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		local now = os.clock()
		if now >= nextSpawn then
			nextSpawn = now + Economy.LaneSpawnInterval
			spawnWalker(folder)
		end

		-- Iterate a copy: walkers that reach the end are removed mid-loop.
		for _, walker in table.clone(walkers) do
			walker.travelled += Economy.LaneSpeed * deltaTime
			if walker.travelled >= length then
				removeWalker(walker)
			else
				local position = from + direction * walker.travelled
				walker.model:PivotTo(CFrame.lookAt(position, position + direction))
			end
		end
	end)
end

return LaneService
