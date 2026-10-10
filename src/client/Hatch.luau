--[[
	Hatch: the egg-opening reveal. The egg shakes harder and harder, cracks in
	a flash, and shows the pet. Rarer pets get a longer build-up, a colored
	flash, a spinning glow, and for Secret and Cosmic a full-screen moment.
	The server already decided the pet; this only shows it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Ui = require(script.Parent.Ui)

local Hatch = {}

local overlay = Ui.Frame("Hatch", Ui.Gui, Color3.new(0, 0, 0), 1)
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.ZIndex = 20

local rays = Ui.Frame("Rays", overlay, Color3.new(1, 1, 1), 1)
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.fromScale(0.5, 0.42)
rays.Size = UDim2.fromOffset(360, 360)
rays.ZIndex = 21
Ui.Corner(rays, 180)

local eggFrame = Ui.Frame("Egg", overlay, Color3.new(1, 1, 1))
eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
eggFrame.Position = UDim2.fromScale(0.5, 0.42)
eggFrame.Size = UDim2.fromOffset(170, 215)
eggFrame.ZIndex = 22
Ui.Corner(eggFrame, 90)
Ui.Stroke(eggFrame, 5)
local eggBand = Ui.Frame("Band", eggFrame, Color3.new(1, 1, 1))
eggBand.AnchorPoint = Vector2.new(0.5, 0.5)
eggBand.Position = UDim2.fromScale(0.5, 0.55)
eggBand.Size = UDim2.new(1, 0, 0, 22)
eggBand.ZIndex = 23

local flash = Ui.Frame("Flash", overlay, Color3.new(1, 1, 1), 1)
flash.Size = UDim2.fromScale(1, 1)
flash.ZIndex = 24

local card = Ui.Frame("Card", overlay, Color3.new(0, 0, 0), 1)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.45)
card.Size = UDim2.fromOffset(520, 280)
card.ZIndex = 25
card.Visible = false
Ui.List(card, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center

local lines: { TextLabel } = {}
for index, height in { 30, 76, 44, 34, 34 } do
	local line = Ui.Label(`Line{index}`, card, "", Color3.new(1, 1, 1))
	line.LayoutOrder = index
	line.Size = UDim2.new(1, 0, 0, height)
	line.ZIndex = 25
	lines[index] = line
end

local queue: { any } = {}
local running = false

local function play(message: any)
	local petId = message.id
	local pet = PetConfig.Pets[petId]
	if pet == nil then
		return
	end
	local tier = PetConfig.RarityIndex[pet.rarity]
	local mutationId = if type(message.mutation) == "string" and PetInfo.MutationsById[message.mutation]
		then message.mutation
		else nil
	local mutation = mutationId and PetInfo.MutationsById[mutationId]
	local egg = PetConfig.EggsById[message.egg]
	local rarityColor = Ui.RarityTextColor(pet.rarity)

	overlay.Visible = true
	card.Visible = false
	eggFrame.Visible = true
	eggFrame.Rotation = 0
	eggFrame.Size = UDim2.fromOffset(170, 215)
	eggFrame.BackgroundColor3 = if egg then Ui.Rgb(egg.color) else Color3.new(1, 1, 1)
	eggBand.BackgroundColor3 = if egg then Ui.Rgb(egg.accent) else Color3.new(1, 1, 1)
	rays.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.4 }):Play()

	-- Wobble harder and faster. Rarer pets shake a little longer, as a hint.
	local steps = 12 + math.min(tier, 8)
	for step = 1, steps do
		local angle = 5 + step * 1.5
		eggFrame.Rotation = if step % 2 == 0 then angle else -angle
		task.wait(math.max(0.04, 0.14 - step * 0.006))
	end
	eggFrame.Rotation = 0
	TweenService:Create(eggFrame, TweenInfo.new(0.18), { Size = UDim2.fromOffset(215, 270) }):Play()
	task.wait(0.18)

	-- Crack: a flash in the rarity's color for rare pets, white otherwise.
	flash.BackgroundColor3 = if tier >= 5
		then Ui.RarityColor[pet.rarity]:Lerp(Color3.new(1, 1, 1), 0.4)
		else Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	eggFrame.Visible = false
	if tier >= 4 then
		rays.BackgroundColor3 = rarityColor
		rays.BackgroundTransparency = 0.55
		rays.Size = UDim2.fromOffset(120, 120)
		TweenService:Create(
			rays,
			TweenInfo.new(0.6, Enum.EasingStyle.Back),
			{ Size = UDim2.fromOffset(300 + tier * 30, 300 + tier * 30) }
		):Play()
	end

	lines[1].Text = if message.new == true then "NEW PET!" else ""
	lines[1].TextColor3 = Ui.Gold
	lines[2].Text = PetInfo.Name(petId, mutationId)
	lines[2].TextColor3 = if mutation then Ui.Rgb(mutation.color) else Color3.new(1, 1, 1)
	lines[3].Text = string.upper(pet.rarity) .. (if tier >= 9 then "!!!" elseif tier >= 6 then "!" else "")
	lines[3].TextColor3 = rarityColor
	local odds = if type(message.odds) == "string" then message.odds else ""
	lines[4].Text = odds .. (if mutation then `  •  {mutation.name} x{mutation.multiplier}` else "")
	lines[4].TextColor3 = Color3.fromRGB(220, 220, 240)
	lines[5].Text = `{Format.Cash(PetInfo.Income(petId, mutationId))}/s`
	lines[5].TextColor3 = Ui.Money
	card.Visible = true
	Ui.Pop(card)
	TweenService:Create(flash, TweenInfo.new(if tier >= 9 then 1.4 else 0.6), { BackgroundTransparency = 1 }):Play()

	-- Spin the glow while the card shows; longer for rarer pets.
	local hold = if tier >= 9 then 4.5 elseif tier >= 6 then 3.4 else 2.4
	local started = os.clock()
	while os.clock() - started < hold do
		rays.Rotation += 2
		if tier >= 10 then
			rays.BackgroundColor3 = Color3.fromHSV((os.clock() * 0.4) % 1, 0.8, 1)
		end
		task.wait()
	end

	card.Visible = false
	rays.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	task.wait(0.25)
	overlay.Visible = false
end

-- Plays reveals one after another when several eggs are opened quickly.
function Hatch.Play(message: any)
	table.insert(queue, message)
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(play, table.remove(queue, 1))
			if not ok then
				warn(`[Hatch] {err}`)
				overlay.Visible = false
			end
		end
		running = false
	end)
end

return Hatch
