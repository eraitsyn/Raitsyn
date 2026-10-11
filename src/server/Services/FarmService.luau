--!strict
-- Draws a player's farm for everyone to see: pet models on their pads with a
-- name / rarity / income label, locked pads and sections, and the eggs
-- sitting in the hatchery's incubators. It only reads the profile; the game
-- rules live in Session. Rendering diffs against what is already there, so
-- calling it after every change is cheap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Map = require(Config:WaitForChild("Map"))
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local EggModel = require(Shared:WaitForChild("Models"):WaitForChild("EggModel"))
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))
local MapBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapBuilder"))
local Schema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Schema"))

type PlotHandles = MapBuilder.PlotHandles

local LABEL_DISTANCE = 80
local HEADING_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local BODY_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

type PadState = { petId: string, species: string, variant: number, model: Model, rate: TextLabel }
type PlotState = {
	pads: { [number]: PadState },
	padSlots: number,
	eggs: { [number]: { rarity: string, model: Model } },
}

local FarmService = {}

local states: { [PlotHandles]: PlotState } = {}

local function variantName(order: number): string
	local variant = Pets.variants[order + 1]
	return if variant then variant.id else "Normal"
end

local function label(parent: Instance, text: string, y: number, height: number, colour: Color3, font: Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.Position = UDim2.fromScale(0, y)
	l.Text = text
	l.TextScaled = true
	l.FontFace = font
	l.TextColor3 = colour
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function petLabel(model: Model, speciesId: string, variant: string, height: number): TextLabel
	local species = Pets.byId[speciesId]
	local rarity = Rarities.byId[species.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(170, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.6, 0)
	gui.MaxDistance = LABEL_DISTANCE
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart :: BasePart
	local nameColour = if rarity.id == Rarities.secretId then Color3.fromRGB(230, 200, 255) else rarity.color
	local title = if variant ~= "Normal" then `{variant} {species.name}` else species.name
	label(gui, title, 0, 0.4, nameColour, HEADING_FONT)
	label(gui, rarity.name, 0.38, 0.27, nameColour:Lerp(Color3.new(1, 1, 1), 0.35), BODY_FONT)
	local rate = label(gui, "", 0.65, 0.35, Color3.fromRGB(255, 220, 90), HEADING_FONT)
	gui.Parent = model
	return rate
end

local function clearPad(state: PlotState, pad: number)
	local current = state.pads[pad]
	if current then
		current.model:Destroy()
		state.pads[pad] = nil
	end
end

local function updatePadLocks(plot: PlotHandles, padSlots: number)
	for index, pad in plot.pads do
		local unlocked = index <= padSlots
		pad.Color = if unlocked then MapBuilder.Palette.pad else MapBuilder.Palette.padLocked
		pad.Transparency = if unlocked then 0 else 0.15
		plot.padLocks[index].Enabled = not unlocked
	end
	for section, gate in plot.sectionGates do
		local firstPad = (section - 1) * Map.padsPerSection + 1
		local open = firstPad <= padSlots
		local closed = gate:GetAttribute("ClosedCFrame") :: CFrame
		-- An open gate swings 100 degrees about its hinge end.
		gate.CFrame = if open
			then closed * CFrame.new(0, 0, -gate.Size.Z / 2) * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(
				0,
				0,
				gate.Size.Z / 2
			)
			else closed
		local sign = plot.sectionSigns[section]
		sign.Enabled = not open
		local text = sign:FindFirstChildOfClass("TextLabel")
		if text then
			text.Text = "🔒 Unlock with Farm Capacity\nand Farm Expansion upgrades"
		end
	end
end

local function updateIncubators(plot: PlotHandles, state: PlotState, incubator: { Schema.IncubatorSlot }, slots: number)
	for index, pedestal in plot.incubators do
		local available = index <= slots
		pedestal.Color = if available then Color3.fromRGB(176, 170, 162) else Color3.fromRGB(110, 106, 102)
		local slot = incubator[index]
		local shown = state.eggs[index]
		if slot == nil or (shown and shown.rarity ~= slot.r) then
			if shown then
				shown.model:Destroy()
				state.eggs[index] = nil
			end
		end
		if slot and state.eggs[index] == nil then
			local egg = EggModel.build(slot.r, 0.9)
			egg:PivotTo(CFrame.new(pedestal.CFrame.Position + Vector3.new(0, pedestal.Size.X / 2, 0)))
			egg:SetAttribute("Incubator", index)
			egg.Parent = plot.petsFolder
			state.eggs[index] = { rarity = slot.r, model = egg }
		end
	end
end

export type RenderInput = {
	data: Schema.Profile,
	padSlots: number,
	incubators: number,
	incomeMultiplier: number,
}

-- Brings the plot's visuals in line with the profile.
function FarmService.render(plot: PlotHandles, input: RenderInput)
	local state = states[plot]
	if state == nil then
		state = { pads = {}, padSlots = -1, eggs = {} }
		states[plot] = state
	end
	local data = input.data

	if state.padSlots ~= input.padSlots then
		updatePadLocks(plot, input.padSlots)
		state.padSlots = input.padSlots
	end

	for padIndex = 1, Economy.maxPadSlots do
		local petId = if padIndex <= input.padSlots then data.placed[tostring(padIndex)] else nil
		local pet = if petId then data.pets[petId] else nil
		local current = state.pads[padIndex]
		if pet == nil then
			clearPad(state, padIndex)
		elseif current == nil or current.petId ~= petId or current.species ~= pet.s or current.variant ~= pet.v then
			clearPad(state, padIndex)
			local variant = variantName(pet.v)
			local model, height = PetModel.build(pet.s, variant)
			local pad = plot.pads[padIndex]
			-- Pets face the gate (plot-local +Z) so visitors see their faces.
			model:PivotTo(
				CFrame.lookAt(
					pad.CFrame.Position + Vector3.new(0, pad.Size.Y / 2, 0),
					pad.CFrame.Position - plot.cframe.LookVector
				)
			)
			model:SetAttribute("PadIndex", padIndex)
			model:SetAttribute("PetId", petId)
			local rate = petLabel(model, pet.s, variant, height)
			model.Parent = plot.petsFolder
			state.pads[padIndex] = {
				petId = petId :: string,
				species = pet.s,
				variant = pet.v,
				model = model,
				rate = rate,
			}
		end
		local shown = state.pads[padIndex]
		if shown and pet then
			shown.rate.Text = Format.rate(Income.petRate(pet.s, variantName(pet.v), input.incomeMultiplier))
		end
	end

	updateIncubators(plot, state, data.incubator, input.incubators)
end

-- Removes everything a player's farm put into the world.
function FarmService.clear(plot: PlotHandles)
	local state = states[plot]
	if state then
		for pad in state.pads do
			clearPad(state, pad)
		end
		for _, egg in state.eggs do
			egg.model:Destroy()
		end
	end
	states[plot] = nil
	plot.petsFolder:ClearAllChildren()
	updatePadLocks(plot, 0)
	-- An open plot shows plain closed sections, not lock icons and upgrade hints.
	for _, lock in plot.padLocks do
		lock.Enabled = false
	end
	for _, sign in plot.sectionSigns do
		sign.Enabled = false
	end
	for _, pedestal in plot.incubators do
		pedestal.Color = Color3.fromRGB(176, 170, 162)
	end
end

return FarmService
