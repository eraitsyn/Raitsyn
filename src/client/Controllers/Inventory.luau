--!strict
-- The Pets panel: a grid of pet cards with sort, rarity filters and a
-- capacity counter, a detail pane with Place / Remove / Follow / Lock /
-- Release, bulk release by rarity, and an Eggs tab.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Costs = require(Logic:WaitForChild("Costs"))
local Format = require(Logic:WaitForChild("Format"))
local Income = require(Logic:WaitForChild("Income"))
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Dialog = require(UI:WaitForChild("Dialog"))
local Kit = require(UI:WaitForChild("Kit"))
local PetCard = require(UI:WaitForChild("PetCard"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))
local Hatch = require(script.Parent:WaitForChild("Hatch"))

local Inventory = {}

local SORTS = { "Income", "Rarity", "Newest", "Name" }

local function request(name: string, ...: any): boolean
	local response = Net.request(name, ...)
	if not response.ok then
		Root.toastError(response.err)
	end
	return response.ok
end

local function petValue(pet: State.Pet): number
	return Income.petBase(pet.s, State.variantId(pet.v))
end

local function rarityOrder(pet: State.Pet): number
	local species = Pets.byId[pet.s]
	return if species then Rarities.byId[species.rarity].order else 0
end

function Inventory.start()
	local panel = Kit.panel("Pets", Vector2.new(900, 560), Theme.color.blue)
	local body = panel.body
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Inventory", handle)

	local sortIndex = 1
	local filter: { [string]: boolean } = {}
	local selected: string? = nil
	local tab = "Pets"

	-- Top bar: tabs, capacity, sort, bulk release
	local top = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = body,
	})
	local petsTab = Kit.button({
		text = "Pets",
		colour = Theme.color.blue,
		size = UDim2.fromOffset(100, 44),
		textSize = 20,
		parent = top,
	})
	local eggsTab = Kit.button({
		text = "Eggs",
		colour = Theme.color.grey,
		size = UDim2.fromOffset(100, 44),
		position = UDim2.fromOffset(108, 0),
		textSize = 20,
		parent = top,
	})
	local capacity = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(170, 44),
		Position = UDim2.fromOffset(222, 0),
		Parent = top,
	})
	local sortButton = Kit.button({
		text = "Sort: Income",
		colour = Theme.color.purple,
		size = UDim2.fromOffset(160, 44),
		position = UDim2.new(1, -330, 0, 0),
		textSize = 18,
		parent = top,
	})
	local bulkButton = Kit.button({
		text = "Release...",
		colour = Theme.color.red,
		size = UDim2.fromOffset(160, 44),
		position = UDim2.new(1, -164, 0, 0),
		textSize = 18,
		parent = top,
	})

	-- Rarity filter chips
	local chips = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 54),
		Parent = body,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local chipButtons: { [string]: TextButton } = {}

	-- Pets grid and detail pane
	local grid = Kit.scroll({
		Name = "Grid",
		Size = UDim2.new(1, -290, 1, -96),
		Position = UDim2.fromOffset(0, 94),
		Parent = body,
	})
	Kit.grid(UDim2.fromOffset(126, 156), 8).Parent = grid
	Kit.padding(4).Parent = grid
	local empty = Kit.label({
		Text = "No pets yet. Roll an egg and hatch it at your Hatchery!",
		FontFace = Theme.font.bold,
		TextSize = 20,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, -290, 0, 80),
		Position = UDim2.fromOffset(0, 140),
		Visible = false,
		Parent = body,
	})

	local detail = Kit.new("Frame", {
		Name = "Detail",
		BackgroundColor3 = Theme.color.panelAlt,
		Size = UDim2.new(0, 276, 1, -96),
		Position = UDim2.new(1, -276, 0, 94),
		Parent = body,
	}, { Kit.corner(UDim.new(0, 14)) })
	local detailView = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 120),
		Parent = detail,
	})
	local detailName = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 24,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 120),
		Parent = detail,
	})
	local detailInfo = Kit.label({
		FontFace = Theme.font.body,
		TextSize = 17,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 148),
		Parent = detail,
	})
	local actions = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 108),
		Position = UDim2.new(0, 8, 1, -170),
		Parent = detail,
	}, { Kit.grid(UDim2.fromOffset(126, 48), 6) })
	local placeButton =
		Kit.button({ text = "Place", colour = Theme.color.green, textSize = 18, layoutOrder = 1, parent = actions })
	local followButton =
		Kit.button({ text = "Follow", colour = Theme.color.blue, textSize = 18, layoutOrder = 2, parent = actions })
	local lockButton =
		Kit.button({ text = "Lock", colour = Theme.color.purple, textSize = 18, layoutOrder = 3, parent = actions })
	local releaseButton =
		Kit.button({ text = "Release", colour = Theme.color.red, textSize = 18, layoutOrder = 4, parent = actions })
	-- always shown, under the per-pet actions
	Kit.button({
		text = "Place Best",
		colour = Theme.color.coinDark,
		textSize = 18,
		size = UDim2.new(1, -16, 0, 50),
		position = UDim2.new(0, 8, 1, -58),
		parent = detail,
		onClick = function()
			task.spawn(request, "PlaceBest")
		end,
	})

	-- Eggs tab
	local eggsView = Kit.scroll({
		Name = "EggsView",
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		Visible = false,
		Parent = body,
	})
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = eggsView
	local eggRows: { [string]: { frame: Frame, count: TextLabel } } = {}
	for i, rarity in Rarities.list do
		local row = Kit.new("Frame", {
			BackgroundColor3 = Theme.rarity(rarity.id):Lerp(Color3.new(1, 1, 1), 0.82),
			Size = UDim2.new(1, -12, 0, 56),
			LayoutOrder = i,
			Parent = eggsView,
		}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(Theme.rarity(rarity.id), 2) })
		Kit.label({
			Text = `{Theme.icon.egg}  {rarity.name} Egg`,
			FontFace = Theme.font.heading,
			TextSize = 22,
			TextColor3 = Theme.shade(Theme.rarity(rarity.id), 0.15),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(300, 56),
			Position = UDim2.fromOffset(16, 0),
			Parent = row,
		})
		local count = Kit.label({
			FontFace = Theme.font.heading,
			TextSize = 22,
			Size = UDim2.fromOffset(80, 56),
			Position = UDim2.fromOffset(320, 0),
			Parent = row,
		})
		Kit.label({
			Text = `Hatch time {Format.duration(rarity.hatchSeconds)} base`,
			FontFace = Theme.font.body,
			TextSize = 16,
			TextColor3 = Theme.color.muted,
			Size = UDim2.fromOffset(200, 56),
			Position = UDim2.fromOffset(400, 0),
			Parent = row,
		})
		Kit.button({
			text = "Hatch",
			colour = Theme.color.green,
			size = UDim2.fromOffset(120, 46),
			position = UDim2.new(1, -130, 0, 5),
			textSize = 18,
			parent = row,
			onClick = function()
				if not App.nearHatchery() then
					Root.toast("Walk to your Hatchery to hatch eggs", "info")
					return
				end
				task.spawn(request, "Hatch", rarity.id, 1)
			end,
		})
		eggRows[rarity.id] = { frame = row, count = count }
	end

	-- Cards
	local cards: { [string]: PetCard.Card } = {}
	local cardSpecies: { [string]: string } = {}
	local detailModel: ViewportFrame? = nil
	local refreshDetail: () -> ()

	local function selectPet(petId: string?)
		if selected and cards[selected] then
			cards[selected].setSelected(false)
		end
		selected = petId
		if petId and cards[petId] then
			cards[petId].setSelected(true)
		end
		refreshDetail()
	end

	local function sortKey(petId: string): (number, string)
		local pet = State.data.pets[petId]
		local mode = SORTS[sortIndex]
		if mode == "Income" then
			return -petValue(pet), petId
		elseif mode == "Rarity" then
			return -rarityOrder(pet) * 1e6 - petValue(pet), petId
		elseif mode == "Newest" then
			return -pet.t, petId
		end
		return 0, Pets.byId[pet.s].name .. petId
	end

	local function refreshCards()
		local data = State.data
		-- add, update, remove
		for petId, pet in data.pets do
			local card: PetCard.Card? = cards[petId]
			if card and cardSpecies[petId] ~= `{pet.s}:{pet.v}` then
				card.button:Destroy()
				cards[petId] = nil
				card = nil
			end
			if card == nil then
				local newCard = PetCard.new(pet, UDim2.fromOffset(126, 156))
				newCard.button.Parent = grid
				newCard.button.Activated:Connect(function()
					selectPet(petId)
				end)
				cards[petId] = newCard
				cardSpecies[petId] = `{pet.s}:{pet.v}`
				card = newCard
			end
			(card :: PetCard.Card).update(
				pet,
				State.stats.incomeMultiplier,
				State.padOf(petId) ~= nil,
				State.isFollowing(petId)
			)
		end
		for petId, card in cards do
			if data.pets[petId] == nil then
				card.button:Destroy()
				cards[petId] = nil
				cardSpecies[petId] = nil
				if selected == petId then
					selected = nil
				end
			end
		end
		-- order and filter
		local ids = {}
		for petId in cards do
			table.insert(ids, petId)
		end
		table.sort(ids, function(a, b)
			local ka, sa = sortKey(a)
			local kb, sb = sortKey(b)
			if ka ~= kb then
				return ka < kb
			end
			return sa < sb
		end)
		local filtered = next(filter) ~= nil
		for order, petId in ids do
			local card = cards[petId]
			card.button.LayoutOrder = order
			local species = Pets.byId[data.pets[petId].s]
			card.button.Visible = not filtered or filter[species.rarity] == true
		end
		local count = State.petCount()
		capacity.Text = `{Theme.icon.pets} {count}/{State.stats.petCapacity}`
		capacity.TextColor3 = if count >= State.stats.petCapacity then Theme.color.red else Theme.color.text
		empty.Visible = tab == "Pets" and count == 0
		refreshDetail()
	end

	refreshDetail = function()
		local petId = selected
		local pet = if petId then State.data.pets[petId] else nil
		if detailModel then
			detailModel:Destroy()
			detailModel = nil
		end
		actions.Visible = true
		if pet == nil or petId == nil then
			detailName.Text = "Pick a pet"
			detailName.TextColor3 = Theme.color.muted
			detailInfo.Text = "Place Best fills your farm with your top earners."
			for _, b in { placeButton, followButton, lockButton, releaseButton } do
				b.root.Visible = false
			end
			return
		end
		for _, b in { placeButton, followButton, lockButton, releaseButton } do
			b.root.Visible = true
		end
		local species = Pets.byId[pet.s]
		local variant = State.variantId(pet.v)
		local model, height = PetModel.build(pet.s, variant)
		detailModel = Kit.viewport(model, height, { Parent = detailView })
		detailName.Text = (if variant ~= "Normal" then variant .. " " else "") .. species.name
		detailName.TextColor3 = Theme.rarity(species.rarity)
		local pad = State.padOf(petId)
		local where = if pad then `On pad {pad}` elseif State.isFollowing(petId) then "Following you" else "In storage"
		detailInfo.Text = `{Rarities.byId[species.rarity].name} · {Format.rate(
			Income.petRate(pet.s, variant, State.stats.incomeMultiplier)
		)}\n{where}`
		placeButton.setText(if pad then "Remove" else "Place")
		followButton.setText(if State.isFollowing(petId) then "Unfollow" else "Follow")
		lockButton.setText(if pet.lk then "Unlock" else "Lock")
		releaseButton.setEnabled(not pet.lk and pad == nil and not State.isFollowing(petId))
	end

	placeButton.face.Activated:Connect(function()
		local petId = selected
		if petId == nil then
			return
		end
		local pad = State.padOf(petId)
		if pad then
			task.spawn(request, "Remove", pad)
		else
			local free = Hatch.firstFreePad()
			if free == nil then
				Root.toast("Your farm is full. Open Farm to swap a pet.", "info")
				return
			end
			task.spawn(request, "Place", petId, free)
		end
	end)
	followButton.face.Activated:Connect(function()
		local petId = selected
		if petId then
			task.spawn(request, "SetFollowing", petId, not State.isFollowing(petId))
		end
	end)
	lockButton.face.Activated:Connect(function()
		local petId = selected
		local pet = petId and State.data.pets[petId]
		if petId and pet then
			task.spawn(request, "SetLocked", petId, not pet.lk)
		end
	end)
	releaseButton.face.Activated:Connect(function()
		local petId = selected
		local pet = petId and State.data.pets[petId]
		if petId == nil or pet == nil or not releaseButton.enabled() then
			if pet and pet.lk then
				Root.toast("Unlock this pet before releasing it", "info")
			end
			return
		end
		local species = Pets.byId[pet.s]
		local refund = Costs.releaseRefund(species.rarity)
		Dialog.confirm(
			"Release pet?",
			`{species.name} will be gone for good. You get {Format.coins(refund)}.`,
			"Release",
			Theme.color.red,
			function()
				task.spawn(request, "Release", { petId })
			end
		)
	end)
	bulkButton.face.Activated:Connect(function()
		-- Releases the filtered rarity when exactly one chip is on, otherwise the
		-- most common rarity that has anything to release.
		local only: string? = nil
		local active = 0
		for id in filter do
			active += 1
			only = id
		end
		local options = {}
		for _, rarity in Rarities.list do
			local count = 0
			for petId, pet in State.data.pets do
				local species = Pets.byId[pet.s]
				if
					species.rarity == rarity.id
					and not pet.lk
					and pet.v == 0
					and State.padOf(petId) == nil
					and not State.isFollowing(petId)
				then
					count += 1
				end
			end
			if count > 0 and (active ~= 1 or rarity.id == only) then
				table.insert(options, { rarity = rarity, count = count })
			end
		end
		if #options == 0 then
			Root.toast("Nothing to release: locked, placed, following and Shiny or better pets are always kept", "info")
			return
		end
		local option = options[1]
		Dialog.confirm(
			`Release all {option.rarity.name}?`,
			`Releases {option.count} unlocked, stored, Normal {option.rarity.name} pets for {Format.coins(
				option.count * option.rarity.releaseRefund
			)}. Locked, placed, following, Shiny and Rainbow pets are kept. (Filter one rarity to pick a different one.)`,
			"Release all",
			Theme.color.red,
			function()
				task.spawn(request, "ReleaseRarity", option.rarity.id)
			end
		)
	end)

	for i, rarity in Rarities.list do
		local chip = Kit.new("TextButton", {
			Text = rarity.name,
			FontFace = Theme.font.bold,
			TextSize = 15,
			TextColor3 = Theme.rarity(rarity.id),
			BackgroundColor3 = Theme.color.panelAlt,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(104, 30),
			LayoutOrder = i,
			Parent = chips,
		}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.rarity(rarity.id), 2) })
		chipButtons[rarity.id] = chip
		chip.Activated:Connect(function()
			local on = not filter[rarity.id]
			if on then
				filter[rarity.id] = true
			else
				filter[rarity.id] = nil
			end
			chip.BackgroundColor3 = if on then Theme.rarity(rarity.id) else Theme.color.panelAlt
			chip.TextColor3 = if on then Theme.color.white else Theme.rarity(rarity.id)
			refreshCards()
		end)
	end

	sortButton.face.Activated:Connect(function()
		sortIndex = sortIndex % #SORTS + 1
		sortButton.setText(`Sort: {SORTS[sortIndex]}`)
		refreshCards()
	end)

	local function refreshEggs()
		for id, row in eggRows do
			local count = State.data.eggs[id] or 0
			row.count.Text = `x{count}`
			row.frame.Visible = count > 0
		end
	end

	local function setTab(name: string)
		tab = name
		local pets = name == "Pets"
		petsTab.setColour(if pets then Theme.color.blue else Theme.color.grey)
		eggsTab.setColour(if pets then Theme.color.grey else Theme.color.blue)
		grid.Visible = pets
		detail.Visible = pets
		chips.Visible = pets
		sortButton.root.Visible = pets
		bulkButton.root.Visible = pets
		eggsView.Visible = not pets
		capacity.Text = if pets
			then `{Theme.icon.pets} {State.petCount()}/{State.stats.petCapacity}`
			else `{Theme.icon.egg} {State.eggTotal()}/{State.stats.eggCapacity}`
		empty.Visible = pets and State.petCount() == 0
		refreshEggs()
	end
	petsTab.face.Activated:Connect(function()
		setTab("Pets")
	end)
	eggsTab.face.Activated:Connect(function()
		setTab("Eggs")
	end)

	-- Rebuilding cards only while the panel is open keeps the closed panel free.
	local dirty = true
	State.changed:Connect(function(key)
		if key == "pets" or key == "placed" or key == "following" or key == "@stats" or key == "@rate" then
			dirty = true
			if Root.isOpen(handle) then
				dirty = false
				refreshCards()
			end
		elseif key == "eggs" and Root.isOpen(handle) then
			setTab(tab)
		end
	end)
	handle.onOpen = function()
		if dirty then
			dirty = false
			refreshCards()
		end
		setTab(tab)
	end
end

return Inventory
