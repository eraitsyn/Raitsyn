--[[
	StealService: stealing gods from other bases, and the base lock.

	A thief holds the Steal prompt on someone else's god, carries a copy of it,
	and must walk back onto their own plot. The god only changes owner in saved
	data at that moment, in one step, so nothing is duplicated or lost if
	either player leaves halfway.

	Server checks, because clients can fire prompts early and move their own
	characters: the hold must really last StealHoldDuration, the thief must be
	in reach, and arriving home faster than MaxCarrySpeed allows cancels the steal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GodConfig = require(ReplicatedStorage.Shared.Config.Gods)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local GodFactory = require(script.Parent.Parent.GodFactory)
local Reach = require(script.Parent.Parent.Reach)
local GodService = require(script.Parent.GodService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

type Steal = {
	thief: Player,
	thiefState: PlotState,
	victimState: PlotState,
	key: string,
	godId: string,
	slotModel: Model,
	carry: Model,
	startedAt: number,
	minDuration: number,
	previousWalkSpeed: number,
}

local HOLD_TOLERANCE = 0.25 -- seconds of network slack allowed on the hold
local DEFAULT_WALK_SPEED = 16

local steals: { [Player]: Steal } = {}
local holdStarts: { [Player]: { prompt: ProximityPrompt, at: number, endedAt: number? } } = {}

local StealService = {}

local function setSlotFaded(model: Model, faded: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if faded then 0.7 else 0
		end
	end
	model:SetAttribute("Stealing", if faded then true else nil)
end

-- A copy of the god welded above the thief's head. Destroyed with the character.
local function attachCarry(godId: string, root: BasePart): Model
	local carry = GodFactory.Build(godId)
	carry.Name = "CarriedGod"
	local carryRoot = carry.PrimaryPart :: BasePart
	for _, part in carry:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			if part ~= carryRoot then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = carryRoot
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	carry:PivotTo(root.CFrame * CFrame.new(0, 3, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carryRoot
	weld.Parent = carryRoot
	carry.Parent = root.Parent
	return carry
end

local function finish(steal: Steal, result: string)
	steals[steal.thief] = nil
	steal.carry:Destroy()

	local character = steal.thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = steal.previousWalkSpeed
	end

	if result == "Stole" then
		-- Ownership moves in one step: out of the victim's save, into the thief's.
		local godId = GodService.Take(steal.victimState, steal.key)
		if godId then
			GodService.Give(steal.thiefState, godId)
		end
		Gate.Notify(steal.thief, "Stole", steal.godId)
		if steal.victimState.player.Parent == Players then
			Gate.Notify(steal.victimState.player, "WasStolen", steal.godId)
		end
	else
		if steal.slotModel.Parent then
			setSlotFaded(steal.slotModel, false)
		end
		if steal.thief.Parent == Players then
			Gate.Notify(steal.thief, result, steal.godId)
		end
	end
end

local function tryStartSteal(thief: Player, victimState: PlotState, key: string, model: Model, prompt: ProximityPrompt)
	local hold = holdStarts[thief]
	holdStarts[thief] = nil
	if not Gate.AllowPrompt(thief) then
		return
	end
	-- The prompt's hold is timed on the client; time it again here. A hold that
	-- was let go early (endedAt set too soon) does not count either.
	local minimum = Economy.StealHoldDuration - HOLD_TOLERANCE
	if
		hold == nil
		or hold.prompt ~= prompt
		or os.clock() - hold.at < minimum
		or (hold.endedAt ~= nil and hold.endedAt - hold.at < minimum)
	then
		return
	end

	local thiefState = PlotService.Get(thief)
	local root = Reach.Root(thief)
	if
		thiefState == nil
		or thief == victimState.player
		or root == nil
		or steals[thief] ~= nil
		or victimState.gods[key] ~= model
		or model:GetAttribute("Stealing")
	then
		return
	end
	if not Reach.Within(thief, model:GetPivot().Position, Economy.ReachDistance) then
		return
	end
	if os.clock() < victimState.lockedUntil then
		Gate.Notify(thief, "Locked", nil)
		return
	end
	if DataSchema.FreeSlot(thiefState.data, Economy.SlotsPerBase) == nil then
		Gate.Notify(thief, "BaseFull", nil)
		return
	end

	local godId = victimState.data.Slots[key]
	local homeBase = thiefState.plot:FindFirstChild("Base") :: BasePart
	-- Distance to the nearest possible edge of the thief's plot, not its centre.
	local homeDistance =
		math.max(0, (homeBase.Position - root.Position).Magnitude - math.max(homeBase.Size.X, homeBase.Size.Z) / 2)
	local humanoid = (root.Parent :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid

	local steal: Steal = {
		thief = thief,
		thiefState = thiefState,
		victimState = victimState,
		key = key,
		godId = godId,
		slotModel = model,
		carry = attachCarry(godId, root),
		startedAt = os.clock(),
		minDuration = homeDistance / Economy.MaxCarrySpeed,
		previousWalkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else DEFAULT_WALK_SPEED,
	}
	steals[thief] = steal
	humanoid.WalkSpeed = Economy.CarryWalkSpeed
	setSlotFaded(model, true)

	Gate.Notify(thief, "Stealing", godId)
	Gate.Notify(victimState.player, "BeingStolen", godId)
end

local function attachStealPrompt(state: PlotState, key: string, model: Model)
	local god = GodConfig.Gods[state.data.Slots[key]]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = god.name
	prompt.HoldDuration = Economy.StealHoldDuration
	prompt.MaxActivationDistance = Economy.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Steal")
	prompt:SetAttribute("OwnerUserId", state.player.UserId)
	prompt.Parent = model.PrimaryPart

	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		holdStarts[player] = { prompt = prompt, at = os.clock(), endedAt = nil }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		local hold = holdStarts[player]
		if hold and hold.prompt == prompt then
			hold.endedAt = os.clock()
		end
	end)
	prompt.Triggered:Connect(function(player: Player)
		tryStartSteal(player, state, key, model, prompt)
	end)
end

local function lock(player: Player)
	local state = PlotService.Get(player)
	if state == nil then
		return
	end
	local now = os.clock()
	if now < state.lockReadyAt then
		Gate.Notify(player, "LockCooldown", nil)
		return
	end
	state.lockedUntil = now + Economy.LockDuration
	state.lockReadyAt = now + Economy.LockCooldown
	-- Server time, so clients can show a countdown.
	local serverNow = workspace:GetServerTimeNow()
	state.plot:SetAttribute("LockedUntil", serverNow + Economy.LockDuration)
	player:SetAttribute("LockReadyAt", serverNow + Economy.LockCooldown)

	local base = state.plot:FindFirstChild("Base") :: BasePart
	local shield = state.janitor:Add(Instance.new("Part"))
	shield.Name = "LockShield"
	shield.Anchored = true
	shield.CanCollide = false
	shield.CanQuery = false
	shield.CanTouch = false
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(90, 170, 255)
	shield.Size = Vector3.new(base.Size.X, 24, base.Size.Z)
	shield.CFrame = base.CFrame * CFrame.new(0, 12, 0)
	shield.Parent = state.plot
	state.janitor:Add(task.delay(Economy.LockDuration, function()
		shield:Destroy()
		state.plot:SetAttribute("LockedUntil", nil)
	end))

	Gate.Notify(player, "LockOn", nil)
end

function StealService.Init()
	GodService.OnPlaced = attachStealPrompt

	Gate.Handle("RequestLock", {
		rate = { capacity = 2, perSecond = 0.5 },
		args = {},
	}, lock)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for thief, steal in steals do
			local root = Reach.Root(thief)
			if
				thief.Parent ~= Players
				or PlotService.Get(thief) ~= steal.thiefState
				or PlotService.Get(steal.victimState.player) ~= steal.victimState
				or steal.victimState.gods[steal.key] ~= steal.slotModel
				or root == nil
			then
				finish(steal, "StealFailed")
			elseif now - steal.startedAt > Economy.StealTimeout then
				finish(steal, "StealTimedOut")
			elseif PlotService.IsOnPlot(steal.thiefState.plot, root.Position) then
				if now - steal.startedAt < steal.minDuration then
					warn(`[StealService] {thief.Name} ({thief.UserId}) got home too fast; steal cancelled`)
					finish(steal, "StealFailed")
				elseif DataSchema.FreeSlot(steal.thiefState.data, Economy.SlotsPerBase) == nil then
					finish(steal, "BaseFull")
				else
					finish(steal, "Stole")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		holdStarts[player] = nil
	end)
end

return StealService
