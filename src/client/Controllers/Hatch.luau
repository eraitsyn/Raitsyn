--!strict
-- The hatchery panel (shown at your own Hatching Platform): incubator slots
-- with progress, egg counts with Hatch buttons, Hatch All and Auto Hatch.
-- Also the hatch reveal: the egg wobbles, cracks and the pet pops out on a
-- card with its name, rarity, variant, income and a NEW! stamp.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Format = require(Logic:WaitForChild("Format"))
local Income = require(Logic:WaitForChild("Income"))
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local EggModel = require(Shared:WaitForChild("Models"):WaitForChild("EggModel"))
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local Root = require(Client:WaitForChild("UI"):WaitForChild("Root"))
local Theme = require(Client:WaitForChild("UI"):WaitForChild("Theme"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local Hatch = {}

export type HatchedPet = {
	id: string,
	species: string,
	variant: string,
	rarity: string,
	isNew: boolean,
	isNewVariant: boolean,
	score: number,
}

local function request(name: string, ...: any): boolean
	local response = Net.request(name, ...)
	if not response.ok then
		Root.toastError(response.err)
	end
	return response.ok
end

function Hatch.firstFreePad(): number?
	for pad = 1, State.stats.padSlots do
		if State.data.placed[tostring(pad)] == nil then
			return pad
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Reveal

local queue: { HatchedPet } = {}
local showing = false

local function revealCard(pet: HatchedPet)
	local species = Pets.byId[pet.species]
	local rarityColour = Theme.rarity(pet.rarity)
	local order = Fx.order(pet.rarity)

	local card = Kit.new("Frame", {
		Name = "HatchReveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(380, 470),
		BackgroundColor3 = Theme.color.panel,
		ZIndex = 10,
		Parent = Root.reveal,
	}, { Kit.corner(UDim.new(0, 22)), Kit.stroke(rarityColour, 5) })
	local pop = Kit.new("UIScale", { Scale = 0.5, Parent = card })
	Kit.tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	-- Rotating rays behind the model, in the rarity colour.
	local rays = Kit.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(260, 260),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = card,
	})
	for i = 0, 5 do
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 22, 1, 0),
			Rotation = i * 30,
			BackgroundColor3 = rarityColour,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = rays,
		})
	end

	-- First the egg, wobbling; then the pet.
	local egg = EggModel.build(pet.rarity)
	local view = Kit.viewport(egg, 3.2, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(260, 260),
		ZIndex = 11,
		Parent = card,
	})
	local spin = 0
	local current: Model = egg
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		spin += dt
		rays.Rotation += dt * 25
		if current == egg then
			current:PivotTo(CFrame.Angles(0, 0, math.sin(spin * 18) * 0.25 * math.min(1, spin)))
		else
			current:PivotTo(CFrame.Angles(0, spin * 0.9 + math.pi, 0))
		end
	end)
	local wobbleSeconds = 0.5 + 0.25 * math.min(order, 4)
	task.wait(wobbleSeconds)

	egg:Destroy()
	local model, height = PetModel.build(pet.species, pet.variant)
	local camera = view.CurrentCamera :: Camera
	local focus = Vector3.new(0, height * 0.5, 0)
	local distance = math.max(height, 2) * 2.6 + 3
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.2, distance * 0.25, -distance), focus)
	model.Parent = view
	current = model
	Fx.celebrate(pet.rarity)

	local variantText = if pet.variant ~= "Normal" then `{pet.variant} ` else ""
	Kit.label({
		Text = variantText .. species.name,
		FontFace = Theme.font.heading,
		TextSize = 34,
		TextColor3 = rarityColour,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 296),
		ZIndex = 11,
		Parent = card,
	})
	Kit.label({
		Text = Rarities.byId[pet.rarity].name,
		FontFace = Theme.font.bold,
		TextSize = 22,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 336),
		ZIndex = 11,
		Parent = card,
	})
	local rate = Income.petRate(pet.species, pet.variant, State.stats.incomeMultiplier)
	Kit.label({
		Text = Format.rate(rate),
		FontFace = Theme.font.heading,
		TextSize = 26,
		TextColor3 = Theme.color.coinDark,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 362),
		ZIndex = 11,
		Parent = card,
	})
	if pet.isNew or pet.isNewVariant then
		local stamp = Kit.label({
			Text = if pet.isNew then "NEW!" else `NEW {string.upper(pet.variant)}!`,
			FontFace = Theme.font.heading,
			TextSize = 28,
			TextColor3 = Theme.color.white,
			BackgroundColor3 = Theme.color.red,
			BackgroundTransparency = 0,
			Size = UDim2.fromOffset(150, 44),
			Position = UDim2.fromOffset(-14, 18),
			Rotation = -12,
			ZIndex = 12,
			Parent = card,
		}, true)
		Kit.corner(UDim.new(0, 10)).Parent = stamp
	end

	local done = false
	local buttons = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.new(0, 20, 1, -70),
		ZIndex = 11,
		Parent = card,
	}, { Kit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })
	Kit.button({
		text = "Place",
		colour = Theme.color.blue,
		size = UDim2.fromOffset(150, 54),
		layoutOrder = 1,
		parent = buttons,
		onClick = function()
			local pad = Hatch.firstFreePad()
			if pad == nil then
				Root.toast("Your farm is full. Open Farm to swap pets.", "info")
			else
				task.spawn(request, "Place", pet.id, pad)
			end
			done = true
		end,
	})
	Kit.button({
		text = "OK",
		colour = Theme.color.green,
		size = UDim2.fromOffset(150, 54),
		layoutOrder = 2,
		parent = buttons,
		onClick = function()
			done = true
		end,
	})

	-- Low rarities close on their own; rare ones wait for the player.
	local deadline = os.clock() + (if order <= 3 then 3 else 30)
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	connection:Disconnect()
	Kit.tween(pop, 0.15, { Scale = 0.6 })
	task.wait(0.15)
	card:Destroy()
end

local function drain()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local pet = table.remove(queue, 1) :: HatchedPet
		local ok, err = pcall(function()
			revealCard(pet)
		end)
		if not ok then
			warn("[Hatch] reveal failed:", err)
		end
	end
	showing = false
end

local function onHatched(pets: { HatchedPet })
	local quick = {}
	for _, pet in pets do
		local skip = State.data.settings.skipCommonReveals and Fx.order(pet.rarity) <= 2 and not pet.isNew
		if skip then
			table.insert(quick, Pets.byId[pet.species].name)
		else
			table.insert(queue, pet)
		end
	end
	if #quick > 0 then
		Root.toast(`Hatched {table.concat(quick, ", ")}`, "good")
	end
	task.spawn(drain)
end

--------------------------------------------------------------------------------
-- Panel

function Hatch.start()
	Net.on("Hatched", onHatched)

	local panel = Kit.new("Frame", {
		Name = "HatchPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(700, 190),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = Root.context,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke() })
	Kit.label({
		Text = "Hatchery",
		FontFace = Theme.font.heading,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.fromOffset(16, 6),
		Parent = panel,
	})

	-- Incubators
	local slotsFrame = Kit.new("Frame", {
		Name = "Incubators",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(330, 140),
		Position = UDim2.fromOffset(12, 40),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	type SlotView = { frame: Frame, egg: TextLabel, bar: Kit.Progress, time: TextLabel }
	local slotViews: { SlotView } = {}
	for i = 1, 4 do
		local frame = Kit.new("Frame", {
			Name = `Slot{i}`,
			BackgroundColor3 = Theme.color.panelAlt,
			Size = UDim2.fromOffset(76, 134),
			LayoutOrder = i,
			Parent = slotsFrame,
		}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(Theme.color.panelDeep, 2) })
		local egg = Kit.label({
			Text = "",
			TextSize = 38,
			Size = UDim2.new(1, 0, 0, 60),
			Position = UDim2.fromOffset(0, 8),
			Parent = frame,
		})
		local bar = Kit.progress(Theme.color.green, UDim2.new(1, -14, 0, 12), frame)
		bar.root.Position = UDim2.fromOffset(7, 76)
		local time = Kit.label({
			Text = "Empty",
			FontFace = Theme.font.bold,
			TextSize = 16,
			TextColor3 = Theme.color.muted,
			Size = UDim2.new(1, -6, 0, 36),
			Position = UDim2.fromOffset(3, 92),
			Parent = frame,
		})
		slotViews[i] = { frame = frame, egg = egg, bar = bar, time = time }
	end

	-- Eggs
	local eggList = Kit.new("Frame", {
		Name = "Eggs",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 86),
		Position = UDim2.fromOffset(350, 40),
		Parent = panel,
	}, { Kit.grid(UDim2.fromOffset(108, 40), 6) })
	local eggButtons: { [string]: Kit.Button } = {}
	for i, rarity in Rarities.list do
		eggButtons[rarity.id] = Kit.button({
			text = "",
			colour = Theme.rarity(rarity.id),
			size = UDim2.fromOffset(108, 40),
			textSize = 15,
			layoutOrder = i,
			parent = eggList,
			onClick = function()
				task.spawn(request, "Hatch", rarity.id, 1)
			end,
		})
	end
	local hatchAll = Kit.button({
		text = "Hatch All",
		colour = Theme.color.green,
		size = UDim2.fromOffset(160, 50),
		position = UDim2.fromOffset(350, 130),
		textSize = 22,
		parent = panel,
		onClick = function()
			task.spawn(request, "Hatch", nil, 25)
		end,
	})
	local autoButton = Kit.button({
		text = "Auto: On",
		colour = Theme.color.green,
		size = UDim2.fromOffset(170, 50),
		position = UDim2.fromOffset(520, 130),
		textSize = 20,
		parent = panel,
		onClick = function()
			task.spawn(request, "SetSetting", "autoHatch", not State.data.settings.autoHatch)
		end,
	})

	local function refreshEggs()
		local any = false
		for _, rarity in Rarities.list do
			local count = State.data.eggs[rarity.id] or 0
			local button = eggButtons[rarity.id]
			button.root.Visible = count > 0
			button.setText(`{rarity.name} x{count}`)
			any = any or count > 0
		end
		hatchAll.setEnabled(any)
		local stats = State.stats
		autoButton.root.Visible = stats.autoHatch > 0
		local on = State.data.settings.autoHatch
		autoButton.setText(if on then "Auto: On" else "Auto: Off")
		autoButton.setColour(if on then Theme.color.green else Theme.color.grey)
	end
	State.watch({ "eggs", "settings", "@stats" }, refreshEggs)

	RunService.Heartbeat:Connect(function()
		local show = App.nearHatchery() and not Root.anyPanelOpen()
		panel.Visible = show
		if not show then
			return
		end
		local now = State.now()
		local slots = State.stats.incubators
		for i, view in slotViews do
			view.frame.Visible = i <= math.max(slots, #State.data.incubator)
			local slot = State.data.incubator[i]
			if slot then
				view.egg.Text = Theme.icon.egg
				view.egg.TextColor3 = Theme.rarity(slot.r)
				view.frame.BackgroundColor3 = Theme.rarity(slot.r):Lerp(Color3.new(1, 1, 1), 0.8)
				local total = math.max(0.1, slot.done - slot.start)
				local left = math.max(0, slot.done - now)
				view.bar.set(1 - left / total)
				view.time.Text = if left > 0 then Format.duration(left) else "Hatching!"
			else
				view.egg.Text = ""
				view.frame.BackgroundColor3 = Theme.color.panelAlt
				view.bar.set(0)
				view.time.Text = "Empty"
			end
		end
	end)
end

return Hatch
