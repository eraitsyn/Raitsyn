--[[
	DropperService: droppers, upgraders, the collector and the collect pad.

	Drops are server-owned parts. Their value lives only in the `drops` table on the
	server, so a client can neither change it nor move the part (network owner is nil).
	One Heartbeat loop drives every dropper in the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DropperConfig = require(ReplicatedStorage.Shared.Config.Droppers)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local CurrencyService = require(script.Parent.CurrencyService)

-- Typed loosely to avoid a require cycle with PlotService's PlotState.
type PlotState = any

type Dropper = {
	state: PlotState,
	origin: BasePart,
	interval: number,
	value: number,
	nextAt: number,
}

type Drop = {
	state: PlotState,
	value: number,
	expiresAt: number,
	upgradedBy: { [string]: boolean },
}

local SWEEP_INTERVAL = 1 -- seconds between expired-drop sweeps

local droppers: { [Dropper]: boolean } = {}
local drops: { [BasePart]: Drop } = {}
local dropQueues: { [PlotState]: { BasePart } } = {} -- oldest first, for the per-plot cap

local DropperService = {}

local function removeDrop(part: BasePart)
	local drop = drops[part]
	if drop then
		drops[part] = nil
		local queue = dropQueues[drop.state]
		if queue then
			local index = table.find(queue, part)
			if index then
				table.remove(queue, index)
			end
		end
	end
	part:Destroy()
end

local function spawnDrop(dropper: Dropper)
	local state = dropper.state
	local queue = dropQueues[state]
	if queue == nil then
		return
	end
	if #queue >= Economy.MaxDropsPerPlot then
		removeDrop(queue[1])
	end

	local part = Instance.new("Part")
	part.Name = "Drop"
	part.Size = Vector3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.CanQuery = false
	part.CFrame = dropper.origin.CFrame * CFrame.new(0, -(dropper.origin.Size.Y / 2 + 0.75), 0)
	part.Parent = state.plot:FindFirstChild("Drops")
	-- After parenting: the server simulates this part, so clients cannot move it.
	part:SetNetworkOwner(nil)

	drops[part] = {
		state = state,
		value = dropper.value,
		expiresAt = os.clock() + Economy.DropLifetime,
		upgradedBy = {},
	}
	table.insert(queue, part)
end

local function incomeMultiplier(state: PlotState): number
	return 1 + state.data.Rebirths * Economy.RebirthBonus
end

-- Called by PurchaseService for every item placed in a plot.
function DropperService.OnItemAdded(state: PlotState, itemName: string, model: Model)
	local dropperConfig = DropperConfig.Droppers[itemName]
	if dropperConfig then
		local origin = model:FindFirstChild("DropOrigin", true)
		assert(origin and origin:IsA("BasePart"), `{itemName} needs a part named DropOrigin`)
		local dropper: Dropper = {
			state = state,
			origin = origin,
			interval = dropperConfig.interval,
			value = dropperConfig.value,
			nextAt = os.clock() + dropperConfig.interval,
		}
		droppers[dropper] = true
		state.janitor:Add(function()
			droppers[dropper] = nil
		end)
	end

	local upgraderConfig = DropperConfig.Upgraders[itemName]
	if upgraderConfig then
		local zone = model:FindFirstChild("UpgradeZone", true)
		assert(zone and zone:IsA("BasePart"), `{itemName} needs a part named UpgradeZone`)
		state.janitor:Add(zone.Touched:Connect(function(hit: BasePart)
			local drop = drops[hit]
			-- Each upgrader applies once per drop, so looping a drop through it does nothing.
			if drop and drop.state == state and not drop.upgradedBy[itemName] then
				drop.upgradedBy[itemName] = true
				drop.value *= upgraderConfig.multiplier
			end
		end))
	end
end

-- Wires the collector and collect pad for a plot. Everything is undone by the plot's janitor.
function DropperService.Setup(state: PlotState)
	local plot: Model = state.plot

	local dropsFolder = state.janitor:Add(Instance.new("Folder"))
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = plot

	dropQueues[state] = {}
	state.janitor:Add(function()
		local queue = dropQueues[state]
		dropQueues[state] = nil
		if queue then
			for _, part in queue do
				drops[part] = nil
			end
		end
	end)

	plot:SetAttribute("StoredCash", state.data.StoredCash)

	local collector = plot:FindFirstChild("Collector") :: BasePart
	state.janitor:Add(collector.Touched:Connect(function(hit: BasePart)
		local drop = drops[hit]
		if drop == nil or drop.state ~= state then
			return
		end
		local amount = math.floor(drop.value * incomeMultiplier(state))
		state.data.StoredCash = math.min(Economy.MaxCash, state.data.StoredCash + amount)
		plot:SetAttribute("StoredCash", state.data.StoredCash)
		removeDrop(hit)
	end))

	local collectPad = plot:FindFirstChild("CollectPad") :: BasePart
	state.janitor:Add(collectPad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character == nil or Players:GetPlayerFromCharacter(character) ~= state.player then
			return
		end
		local stored = state.data.StoredCash
		if stored > 0 then
			state.data.StoredCash = 0
			plot:SetAttribute("StoredCash", 0)
			CurrencyService.Add(state.player, stored)
		end
	end))
end

local nextSweep = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for dropper in droppers do
		if now >= dropper.nextAt then
			dropper.nextAt = now + dropper.interval
			spawnDrop(dropper)
		end
	end

	if now >= nextSweep then
		nextSweep = now + SWEEP_INTERVAL
		local expired = {}
		for part, drop in drops do
			if now >= drop.expiresAt then
				table.insert(expired, part)
			end
		end
		for _, part in expired do
			removeDrop(part)
		end
	end
end)

return DropperService
