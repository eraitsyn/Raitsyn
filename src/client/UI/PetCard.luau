--!strict
-- A pet card: 3D preview, name in rarity colour, income, and badges for
-- placed / following / locked / variant. Used by the inventory grid and the
-- pad picker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Pets = require(Shared:WaitForChild("Config"):WaitForChild("Pets"))
local PetModel = require(Shared:WaitForChild("Models"):WaitForChild("PetModel"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local PetCard = {}

export type Card = {
	button: TextButton,
	rate: TextLabel,
	badges: TextLabel,
	update: (pet: { s: string, v: number, lk: boolean }, multiplier: number, placed: boolean, following: boolean) -> (),
	setSelected: (selected: boolean) -> (),
}

local function variantId(order: number): string
	local variant = Pets.variants[order + 1]
	return if variant then variant.id else "Normal"
end

function PetCard.new(pet: { s: string, v: number, lk: boolean }, size: UDim2): Card
	local species = Pets.byId[pet.s]
	local colour = Theme.rarity(species.rarity)
	local button = Kit.new("TextButton", {
		Name = "PetCard",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.82),
		Size = size,
	}, { Kit.corner(UDim.new(0, 12)) })
	local stroke = Kit.stroke(colour, 3) :: UIStroke
	stroke.Parent = button
	local model, height = PetModel.build(pet.s, variantId(pet.v))
	Kit.viewport(model, height, {
		Size = UDim2.new(1, 0, 1, -44),
		Position = UDim2.fromOffset(0, 2),
		Parent = button,
	})
	local prefix = if pet.v > 0 then (if pet.v == 2 then Theme.icon.rainbow else Theme.icon.shiny) .. " " else ""
	Kit.label({
		Text = prefix .. species.name,
		FontFace = Theme.font.bold,
		TextSize = 15,
		TextColor3 = Theme.shade(colour, 0.2),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Size = UDim2.new(1, -8, 0, 20),
		Position = UDim2.new(0, 4, 1, -42),
		Parent = button,
	})
	local rate = Kit.label({
		Text = "",
		FontFace = Theme.font.heading,
		TextSize = 15,
		TextColor3 = Theme.color.coinDark,
		Size = UDim2.new(1, -8, 0, 20),
		Position = UDim2.new(0, 4, 1, -22),
		Parent = button,
	})
	local badges = Kit.label({
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -6, 0, 20),
		Position = UDim2.fromOffset(0, 4),
		Parent = button,
	})

	local card: Card
	card = {
		button = button,
		rate = rate,
		badges = badges,
		update = function(p, multiplier, placed, following)
			rate.Text = Format.rate(Income.petRate(p.s, variantId(p.v), multiplier))
			local icons = {}
			if placed then
				table.insert(icons, Theme.icon.placed)
			end
			if following then
				table.insert(icons, Theme.icon.follow)
			end
			if p.lk then
				table.insert(icons, Theme.icon.lock)
			end
			badges.Text = table.concat(icons, "")
		end,
		setSelected = function(selected)
			stroke.Thickness = if selected then 5 else 3
			stroke.Color = if selected then Theme.color.stroke else colour
		end,
	}
	return card
end

return PetCard
