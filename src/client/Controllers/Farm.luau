--!strict
-- The Farm panel (all 24 pads, Place Best, Remove All, what unlocks the next
-- pad) and the pad picker, which opens from the panel or by clicking or
-- tapping one of your own pads in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Config:WaitForChild("Economy"))
local Format = require(Logic:WaitForChild("Format"))
local HexTree = require(Config:WaitForChild("HexTree"))
local Income = require(Logic:WaitForChild("Income"))
local Pets = require(Config:WaitForChild("Pets"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local PetCard = require(UI:WaitForChild("PetCard"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))

local Farm = {}

local function request(name: string, ...: any): boolean
	local response = Net.request(name, ...)
	if not response.ok then
		Root.toastError(response.err)
	end
	return response.ok
end

-- Names the hex tiles that still add pads, for the "next pad" hint.
local function padTilesText(): string
	local names = {}
	for _, tile in HexTree.tiles do
		for _, effect in tile.effects do
			if effect.stat == "padSlots" then
				local level = if tile.keystone
					then (if State.data.keystones[tile.id] then 1 else 0)
					else (State.data.hex[tile.id] or 0)
				if level < tile.maxLevel then
					table.insert(names, tile.name)
				end
			end
		end
	end
	if #names == 0 then
		return "Every pad is unlocked."
	end
	return "More pads: " .. table.concat(names, ", ")
end

--------------------------------------------------------------------------------
-- Pad picker

local picker: { handle: Root.PanelHandle, open: (pad: number) -> () }

local function buildPicker()
	local panel = Kit.panel("Choose a pet", Vector2.new(720, 520), Theme.color.green)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	local currentPad = 1
	local info = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -180, 0, 44),
		Parent = panel.body,
	})
	local removeButton = Kit.button({
		text = "Take off pad",
		colour = Theme.color.red,
		size = UDim2.fromOffset(170, 44),
		position = UDim2.new(1, -170, 0, 0),
		textSize = 18,
		parent = panel.body,
		onClick = function()
			task.spawn(request, "Remove", currentPad)
			Root.closePanel()
		end,
	})
	local grid = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.fromOffset(0, 54),
		Parent = panel.body,
	})
	Kit.grid(UDim2.fromOffset(126, 156), 8).Parent = grid
	Kit.padding(4).Parent = grid
	local none = Kit.label({
		Text = "No pets in storage. Hatch more eggs, or take a pet off another pad.",
		FontFace = Theme.font.bold,
		TextSize = 19,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 120),
		Parent = panel.body,
	})

	local function open(pad: number)
		currentPad = pad
		panel.title.Text = `Pad {pad}`
		for _, child in grid:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local occupant = State.data.placed[tostring(pad)]
		removeButton.root.Visible = occupant ~= nil
		if occupant and State.data.pets[occupant] then
			local pet = State.data.pets[occupant]
			info.Text = `Now: {Pets.byId[pet.s].name} ({Format.rate(
				Income.petRate(pet.s, State.variantId(pet.v), State.stats.incomeMultiplier)
			)}). Pick a pet to swap in.`
		else
			info.Text = "Pick a pet to place on this pad."
		end
		-- every pet not already on a pad, best first
		local ids = {}
		for petId in State.data.pets do
			if State.padOf(petId) == nil then
				table.insert(ids, petId)
			end
		end
		table.sort(ids, function(a, b)
			local pa, pb = State.data.pets[a], State.data.pets[b]
			local va = Income.petBase(pa.s, State.variantId(pa.v))
			local vb = Income.petBase(pb.s, State.variantId(pb.v))
			if va ~= vb then
				return va > vb
			end
			return a < b
		end)
		none.Visible = #ids == 0
		for order, petId in ids do
			if order > 60 then
				break -- the best 60 are plenty to choose from
			end
			local pet = State.data.pets[petId]
			local card = PetCard.new(pet, UDim2.fromOffset(126, 156))
			card.update(pet, State.stats.incomeMultiplier, false, State.isFollowing(petId))
			card.button.LayoutOrder = order
			card.button.Parent = grid
			card.button.Activated:Connect(function()
				Root.closePanel()
				task.spawn(request, "Place", petId, pad)
			end)
		end
		Root.openPanel(handle)
	end

	picker = { handle = handle, open = open }
end

function Farm.openPicker(pad: number)
	if pad > State.stats.padSlots then
		Root.toast(`Pad {pad} is locked. {padTilesText()}`, "info")
		return
	end
	picker.open(pad)
end

--------------------------------------------------------------------------------

function Farm.start()
	buildPicker()

	local panel = Kit.panel("Farm", Vector2.new(820, 540), Theme.color.green)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Farm", handle)

	local summary = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -360, 0, 24),
		Parent = panel.body,
	})
	local hint = Kit.label({
		FontFace = Theme.font.body,
		TextSize = 16,
		TextColor3 = Theme.color.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -360, 0, 22),
		Position = UDim2.fromOffset(0, 24),
		Parent = panel.body,
	})
	Kit.button({
		text = "Place Best",
		colour = Theme.color.green,
		size = UDim2.fromOffset(170, 48),
		position = UDim2.new(1, -350, 0, 0),
		textSize = 20,
		parent = panel.body,
		onClick = function()
			task.spawn(request, "PlaceBest")
		end,
	})
	Kit.button({
		text = "Remove All",
		colour = Theme.color.red,
		size = UDim2.fromOffset(170, 48),
		position = UDim2.new(1, -170, 0, 0),
		textSize = 20,
		parent = panel.body,
		onClick = function()
			task.spawn(request, "RemoveAll")
		end,
	})

	local grid = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		Parent = panel.body,
	}, { Kit.grid(UDim2.fromOffset(124, 90), 8) })
	type Cell = { button: TextButton, title: TextLabel, sub: TextLabel }
	local cells: { Cell } = {}
	for pad = 1, Economy.maxPadSlots do
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.color.panelAlt,
			LayoutOrder = pad,
			Parent = grid,
		}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(Theme.color.panelDeep, 2) })
		Kit.label({
			Text = `Pad {pad}`,
			FontFace = Theme.font.bold,
			TextSize = 14,
			TextColor3 = Theme.color.muted,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 4),
			Parent = button,
		})
		local title = Kit.label({
			FontFace = Theme.font.heading,
			TextSize = 17,
			Size = UDim2.new(1, -8, 0, 36),
			Position = UDim2.fromOffset(4, 22),
			Parent = button,
		})
		local sub = Kit.label({
			FontFace = Theme.font.heading,
			TextSize = 15,
			TextColor3 = Theme.color.coinDark,
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 62),
			Parent = button,
		})
		button.Activated:Connect(function()
			Farm.openPicker(pad)
		end)
		cells[pad] = { button = button, title = title, sub = sub }
	end

	local function refresh()
		local slots = State.stats.padSlots
		local used = 0
		for pad, cell in cells do
			local petId = State.data.placed[tostring(pad)]
			local pet = if petId then State.data.pets[petId] else nil
			if pad > slots then
				cell.title.Text = Theme.icon.lock
				cell.title.TextColor3 = Theme.color.muted
				cell.sub.Text = "Locked"
				cell.sub.TextColor3 = Theme.color.muted
				cell.button.BackgroundColor3 = Theme.color.panelDeep
			elseif pet then
				used += 1
				local species = Pets.byId[pet.s]
				cell.title.Text = species.name
				cell.title.TextColor3 = Theme.rarity(species.rarity)
				cell.sub.Text = Format.rate(Income.petRate(pet.s, State.variantId(pet.v), State.stats.incomeMultiplier))
				cell.sub.TextColor3 = Theme.color.coinDark
				cell.button.BackgroundColor3 = Theme.rarity(species.rarity):Lerp(Color3.new(1, 1, 1), 0.82)
			else
				cell.title.Text = "Empty"
				cell.title.TextColor3 = Theme.color.muted
				cell.sub.Text = "Tap to place"
				cell.sub.TextColor3 = Theme.color.greenDark
				cell.button.BackgroundColor3 = Theme.color.panelAlt
			end
		end
		summary.Text = `{used}/{slots} pads in use · {Format.rate(State.rate)}`
		hint.Text = padTilesText()
	end
	State.watch({ "placed", "pets", "hex", "keystones", "@stats", "@rate" }, refresh)

	-- Clicking or tapping one of your own pads in the world opens the picker.
	-- A press that moved (a camera drag or swipe) is not a click.
	local pressedAt: Vector3? = nil
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if isPress(input) then
			pressedAt = if processed then nil else input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed or Root.anyPanelOpen() or not isPress(input) then
			return
		end
		local start = pressedAt
		pressedAt = nil
		if start == nil or (input.Position - start).Magnitude > 12 then
			return
		end
		local plot = App.plot()
		local pads = plot and plot:FindFirstChild("Pads")
		local camera = workspace.CurrentCamera
		if pads == nil or camera == nil then
			return
		end
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { pads }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		if hit then
			local pad = hit.Instance:GetAttribute("PadIndex")
			if type(pad) == "number" then
				Farm.openPicker(pad)
			end
		end
	end)
end

return Farm
