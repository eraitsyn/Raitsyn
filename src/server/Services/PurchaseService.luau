--[[
	PurchaseService: every purchase goes through TryPurchase.

	The client only ever names a button id. Price, prerequisites and ownership all
	come from server config and server state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Buttons = require(ReplicatedStorage.Shared.Config.Buttons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local ButtonGraph = require(ReplicatedStorage.Shared.ButtonGraph)
local Gate = require(script.Parent.Parent.Gate)
local CurrencyService = require(script.Parent.CurrencyService)
local DropperService = require(script.Parent.DropperService)
local PlotService = require(script.Parent.PlotService)

export type Result = "Purchased" | "Unknown" | "NoPlot" | "Owned" | "Locked" | "TooFar" | "Busy" | "TooPoor" | "Error"
export type Source = "prompt" | "remote"

local itemTemplates: Folder

local PurchaseService = {}

-- Checks the config once at boot and fails loudly if anything is wrong.
function PurchaseService.Init()
	local ok, message = ButtonGraph.Check(Buttons)
	assert(ok, `[PurchaseService] invalid button config: {message}`)
	itemTemplates = ServerStorage:WaitForChild("Items") :: Folder
	for id, button in Buttons do
		local template = itemTemplates:FindFirstChild(button.item)
		assert(
			template and template:IsA("Model"),
			`[PurchaseService] {id}: ServerStorage.Items.{button.item} is missing`
		)
	end
end

local function spawnItem(state: PlotService.PlotState, id: string)
	local itemName = Buttons[id].item
	local template = itemTemplates:FindFirstChild(itemName) :: Model
	local model = template:Clone()
	-- Templates are authored around the origin; place them relative to this plot's Base.
	model:PivotTo(state.plot:GetPivot() * template:GetPivot())
	model.Parent = state.plot:FindFirstChild("Items")
	DropperService.OnItemAdded(state, itemName, model)
end

-- Shows pads that are unlocked and not yet owned; hides the rest.
local function refreshPads(state: PlotService.PlotState)
	local pads = state.plot:FindFirstChild("Buttons") :: Folder
	for id in Buttons do
		local pad = pads:FindFirstChild(id) :: BasePart
		local shown = not state.data.Purchased[id] and ButtonGraph.IsUnlocked(Buttons, id, state.data.Purchased)
		pad.Transparency = if shown then (pad:GetAttribute("ShownTransparency") or 0) :: number else 1
		pad.CanCollide = shown
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = shown
		end
	end
end

local function withinReach(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - pad.Position).Magnitude <= Economy.PurchaseDistance
end

function PurchaseService.TryPurchase(player: Player, id: string, source: Source): Result
	local result: Result
	local button = Buttons[id]
	local state = PlotService.Get(player)

	if button == nil then
		result = "Unknown"
	elseif state == nil then
		result = "NoPlot"
	elseif state.data.Purchased[id] then
		result = "Owned"
	elseif not ButtonGraph.IsUnlocked(Buttons, id, state.data.Purchased) then
		result = "Locked"
	elseif
		source == "prompt"
		and not withinReach(player, (state.plot:FindFirstChild("Buttons") :: Folder):FindFirstChild(id) :: BasePart)
	then
		result = "TooFar"
	elseif state.busy then
		result = "Busy"
	else
		state.busy = true
		local ok, outcome = pcall(function(): Result
			if not CurrencyService.TrySpend(player, button.price) then
				return "TooPoor"
			end
			state.data.Purchased[id] = true
			spawnItem(state, id)
			refreshPads(state)
			return "Purchased"
		end)
		state.busy = false
		if ok then
			result = outcome
		else
			warn(`[PurchaseService] {player.Name} buying {id} failed: {outcome}`)
			result = "Error"
		end
	end

	Gate.Notify(player, result, if button then id else nil)
	return result
end

-- Rebuilds owned items in dependency order and wires up a prompt on every pad.
function PurchaseService.Setup(state: PlotService.PlotState)
	for _, id in ButtonGraph.Order(Buttons) do
		if state.data.Purchased[id] then
			spawnItem(state, id)
		end
	end

	local pads = state.plot:FindFirstChild("Buttons") :: Folder
	for id, button in Buttons do
		local prompt = state.janitor:Add(Instance.new("ProximityPrompt"))
		prompt.ActionText = "Buy"
		prompt.ObjectText = `{button.label} ({button.price})`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Economy.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = pads:FindFirstChild(id)

		state.janitor:Add(prompt.Triggered:Connect(function(who: Player)
			-- Only the plot's owner can buy on it.
			if who == state.player then
				PurchaseService.TryPurchase(who, id, "prompt")
			end
		end))
	end

	refreshPads(state)
end

return PurchaseService
