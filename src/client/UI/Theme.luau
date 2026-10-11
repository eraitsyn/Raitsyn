--!strict
-- One visual language for every screen: colours, fonts, sizes. Rarity
-- colours come from config so text, cards, pads and tiles always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rarities"))

local Theme = {}

Theme.font = {
	heading = Font.fromEnum(Enum.Font.FredokaOne),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

Theme.color = {
	text = Color3.fromRGB(44, 48, 66),
	muted = Color3.fromRGB(116, 122, 140),
	white = Color3.new(1, 1, 1),
	panel = Color3.fromRGB(255, 255, 255),
	panelAlt = Color3.fromRGB(243, 245, 250),
	panelDeep = Color3.fromRGB(228, 232, 242),
	stroke = Color3.fromRGB(40, 44, 66),
	coin = Color3.fromRGB(255, 200, 40),
	coinDark = Color3.fromRGB(214, 150, 20),
	green = Color3.fromRGB(88, 204, 104),
	greenDark = Color3.fromRGB(52, 156, 72),
	blue = Color3.fromRGB(74, 156, 255),
	blueDark = Color3.fromRGB(44, 108, 210),
	red = Color3.fromRGB(240, 92, 92),
	redDark = Color3.fromRGB(186, 56, 64),
	purple = Color3.fromRGB(150, 104, 255),
	purpleDark = Color3.fromRGB(104, 66, 206),
	grey = Color3.fromRGB(170, 176, 190),
	greyDark = Color3.fromRGB(120, 126, 142),
	overlay = Color3.fromRGB(12, 14, 24),
	-- the hex tree's blueprint canvas
	blueprint = Color3.fromRGB(18, 28, 52),
	blueprintLine = Color3.fromRGB(46, 70, 118),
}

Theme.radius = UDim.new(0, 14)
Theme.strokeWidth = 3

-- Rarity colour for text on a light background; Secret is drawn dark
-- purple so it stays readable.
function Theme.rarity(rarityId: string): Color3
	if rarityId == Rarities.secretId then
		return Color3.fromRGB(88, 40, 150)
	end
	local rarity = Rarities.byId[rarityId]
	return if rarity then rarity.color else Theme.color.grey
end

-- A darker shade for button shadows and borders.
function Theme.shade(colour: Color3, amount: number?): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount or 0.25)
end

-- Icons are emoji so the game needs no uploaded image assets.
Theme.icon = {
	pets = "🐾",
	farm = "🌾",
	upgrades = "⬢",
	index = "📖",
	daily = "🎁",
	rebirth = "♻️",
	settings = "⚙️",
	home = "🏠",
	hub = "🏛️",
	coin = "💰",
	luck = "🍀",
	lock = "🔒",
	star = "⭐",
	egg = "🥚",
	follow = "👣",
	placed = "🌾",
	shiny = "✨",
	rainbow = "🌈",
	close = "✕",
}

return Theme
