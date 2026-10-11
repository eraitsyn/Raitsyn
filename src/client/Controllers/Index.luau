--!strict
-- The Pet Index: every species, grouped by rarity, with its odds from a
-- Basic roll. Found species show their model and which variants you own;
-- the rest are silhouettes. Each species found adds the Collector's Bonus
-- once its hex tile is owned, so the header says what the Index is worth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Format = require(Logic:WaitForChild("Format"))
local Odds = require(Logic:WaitForChild("Odds"))
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))

local Index = {}

local VARIANT_ICONS = { Normal = "●", Shiny = Theme.icon.shiny, Rainbow = Theme.icon.rainbow }

type Cell = {
	frame: Frame,
	preview: Frame,
	name: TextLabel,
	variants: TextLabel,
	built: boolean,
	found: boolean?,
}

function Index.start()
	local panel = Kit.panel("Pet Index", Vector2.new(880, 580), Theme.color.purple)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Index", handle)

	local summary = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = panel.body,
	})
	local bonus = Kit.label({
		FontFace = Theme.font.body,
		TextSize = 16,
		TextColor3 = Theme.color.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 24),
		Parent = panel.body,
	})
	local scroll = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		Parent = panel.body,
	})
	Kit.list(Enum.FillDirection.Vertical, 10).Parent = scroll
	Kit.padding(4).Parent = scroll

	local cells: { [string]: Cell } = {}
	local order = 0
	for _, rarity in Rarities.list do
		order += 1
		Kit.label({
			Text = rarity.name,
			FontFace = Theme.font.heading,
			TextSize = 24,
			TextColor3 = Theme.rarity(rarity.id),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = order,
			Parent = scroll,
		})
		order += 1
		local row = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = scroll,
		}, { Kit.grid(UDim2.fromOffset(150, 176), 8) })

		local pool: { Pets.Species } = table.clone(Pets.byRarity[rarity.id] or {})
		-- most common first, so each row reads as a chase from left to right
		table.sort(pool, function(a, b)
			return a.weight > b.weight
		end)
		for position, species in pool do
			local colour = Theme.rarity(rarity.id)
			local frame = Kit.new("Frame", {
				Name = species.id,
				BackgroundColor3 = Theme.color.panelAlt,
				LayoutOrder = position,
				Parent = row,
			}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(colour, 2) })
			local preview = Kit.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 96),
				Position = UDim2.fromOffset(4, 4),
				Parent = frame,
			})
			local name = Kit.label({
				FontFace = Theme.font.heading,
				TextSize = 16,
				TextColor3 = colour,
				Size = UDim2.new(1, -8, 0, 20),
				Position = UDim2.fromOffset(4, 102),
				Parent = frame,
			})
			local chance = Odds.basicChance(species.id, "Normal")
				+ Odds.basicChance(species.id, "Shiny")
				+ Odds.basicChance(species.id, "Rainbow")
			Kit.label({
				Text = `1 in {Format.commas(Odds.oneIn(chance))}`,
				FontFace = Theme.font.bold,
				TextSize = 14,
				TextColor3 = Theme.color.muted,
				Size = UDim2.new(1, -8, 0, 18),
				Position = UDim2.fromOffset(4, 124),
				Parent = frame,
			})
			local variants = Kit.label({
				FontFace = Theme.font.bold,
				TextSize = 16,
				RichText = true,
				Size = UDim2.new(1, -8, 0, 22),
				Position = UDim2.fromOffset(4, 146),
				Parent = frame,
			})
			cells[species.id] = {
				frame = frame,
				preview = preview,
				name = name,
				variants = variants,
				built = false,
			}
		end
	end

	-- 3D previews are built the first time the panel opens, then reused. A
	-- species not yet found is drawn as a black silhouette.
	local function paintPreview(speciesId: string, cell: Cell, found: boolean)
		if cell.built and cell.found == found then
			return
		end
		for _, child in cell.preview:GetChildren() do
			child:Destroy()
		end
		local model, height = PetModel.build(speciesId, "Normal")
		for _, part in model:GetDescendants() do
			if part:IsA("ParticleEmitter") or part:IsA("PointLight") then
				part:Destroy()
			end
		end
		local view = Kit.viewport(model, height, {
			ImageColor3 = if found then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
			ImageTransparency = if found then 0 else 0.25,
		})
		view.Parent = cell.preview
		cell.built = true
		cell.found = found
	end

	local function refresh()
		local found = 0
		local masks = State.data.index
		for speciesId, cell in cells do
			local mask = masks[speciesId] or 0
			local has = mask > 0
			if has then
				found += 1
			end
			cell.name.Text = if has then Pets.byId[speciesId].name else "???"
			local parts = {}
			for _, variant in Pets.variants do
				local owned = bit32.band(mask, bit32.lshift(1, variant.order)) ~= 0
				local icon = VARIANT_ICONS[variant.id] or "●"
				local colour = if owned then "#2C3042" else "#C8CCD8"
				local text = if owned then icon else "○"
				table.insert(parts, `<font color="{colour}">{text}</font>`)
			end
			cell.variants.Text = table.concat(parts, "  ")
			cell.frame.BackgroundColor3 = if has then Theme.color.panel else Theme.color.panelDeep
			if panel.root.Visible then
				paintPreview(speciesId, cell, has)
			end
		end
		summary.Text = `{Theme.icon.index} {found}/{#Pets.list} species found`
		local perSpecies = State.stats.collectorBonusPerSpecies
		if perSpecies > 0 then
			bonus.Text = `Collector's Bonus: +{Format.percent(perSpecies * found)} pet income ({Format.percent(
				perSpecies
			)} per species)`
		else
			bonus.Text = "Own the Collector's Bonus hex tile to earn extra income for every species found."
		end
	end

	handle.onOpen = refresh
	State.watch({ "index", "@stats" }, function()
		if panel.root.Visible then
			refresh()
		end
	end)
end

return Index
