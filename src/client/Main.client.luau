--[[
	Client entry point. The client only shows state; every action is a
	ProximityPrompt that the server checks. Hiding other players' prompts here
	is for clarity only.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local EGG_TAG = "IncubatingEgg"
local BIG_REVEAL = { Legendary = true, Mythical = true, Secret = true }

local rarityColors: { [string]: Color3 } = {}
for _, rarity in PetConfig.Rarities do
	rarityColors[rarity.name] = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
end
local eggNames: { [string]: string } = {}
for _, egg in PetConfig.Eggs do
	eggNames[egg.id] = egg.name
end

local function petName(id: string?): string
	local pet = id and PetConfig.Pets[id]
	return if pet then pet.name else "pet"
end

local MESSAGES: { [string]: (id: string?, by: string?) -> string } = {
	BoughtEgg = function(id)
		return `{eggNames[id or ""] or "Egg"} is in your incubator!`
	end,
	NotReady = function()
		return "This egg is not ready yet."
	end,
	Hatched = function(id)
		local pet = id and PetConfig.Pets[id]
		return if pet then `You hatched a {pet.rarity} {pet.name}!` else "You hatched a pet!"
	end,
	ServerHatch = function(id, by)
		local pet = id and PetConfig.Pets[id]
		return `{by or "Someone"} hatched a {if pet then pet.rarity .. " " .. pet.name else "rare pet"}!`
	end,
	Sold = function(id)
		return `Sold {petName(id)}.`
	end,
	TooPoor = function()
		return "Not enough cash."
	end,
	IncubatorsFull = function()
		return "Your incubators are full. Hatch an egg first."
	end,
	PedestalsFull = function()
		return "Your pedestals are full. Sell a pet to make room."
	end,
	LuckUp = function()
		return "Luck upgraded!"
	end,
}

-- HUD --------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "EggHud"
gui.ResetOnSpawn = false

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 16)
toast.Size = UDim2.fromOffset(440, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui

local reveal = Instance.new("TextLabel")
reveal.Name = "Reveal"
reveal.AnchorPoint = Vector2.new(0.5, 0.5)
reveal.Position = UDim2.fromScale(0.5, 0.4)
reveal.Size = UDim2.fromScale(0.7, 0.15)
reveal.BackgroundTransparency = 1
reveal.Font = Enum.Font.GothamBlack
reveal.TextScaled = true
reveal.TextStrokeTransparency = 0
reveal.Visible = false
reveal.Parent = gui

local luckLabel = Instance.new("TextLabel")
luckLabel.Name = "Luck"
luckLabel.AnchorPoint = Vector2.new(0, 1)
luckLabel.Position = UDim2.new(0, 16, 1, -16)
luckLabel.Size = UDim2.fromOffset(160, 40)
luckLabel.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
luckLabel.TextColor3 = Color3.new(1, 1, 1)
luckLabel.Font = Enum.Font.GothamBold
luckLabel.TextScaled = true
luckLabel.Text = "Luck: x1"
luckLabel.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local toastSerial = 0
local function showToast(text: string)
	toastSerial += 1
	local serial = toastSerial
	toast.Text = text
	toast.Visible = true
	task.delay(3, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

local revealSerial = 0
local function showReveal(petId: string)
	local pet = PetConfig.Pets[petId]
	if pet == nil or not BIG_REVEAL[pet.rarity] then
		return
	end
	revealSerial += 1
	local serial = revealSerial
	reveal.Text = `{string.upper(pet.rarity)}!\n{pet.name}`
	reveal.TextColor3 = rarityColors[pet.rarity]
	reveal.Visible = true
	task.delay(3, function()
		if revealSerial == serial then
			reveal.Visible = false
		end
	end)
end

Remotes.Get("Notify").OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.kind) ~= "string" then
		return
	end
	local id = if type(message.id) == "string" then message.id else nil
	local by = if type(message.by) == "string" then message.by else nil
	local format = MESSAGES[message.kind]
	if format then
		showToast(format(id, by))
	end
	if message.kind == "Hatched" and id then
		showReveal(id)
	end
end)

local function updateLuck()
	local luck = player:GetAttribute("Luck")
	luckLabel.Text = `Luck: {Luck.Text(if type(luck) == "number" then luck else 1)}`
end
player:GetAttributeChangedSignal("Luck"):Connect(updateLuck)
updateLuck()

-- Egg countdowns ---------------------------------------------------------

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, shell in CollectionService:GetTagged(EGG_TAG) do
		local readyAt = shell:GetAttribute("ReadyAt")
		local tag = shell:FindFirstChild("EggTag")
		local line = tag and tag:FindFirstChild("Line2")
		if type(readyAt) == "number" and line and line:IsA("TextLabel") then
			local remaining = math.ceil(readyAt - now)
			line.Text = if remaining > 0 then `{remaining}s` else "Ready to hatch!"
		end
	end
end)

-- Prompts: only show your own base's prompts ----------------------------

local function filterPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("OwnerUserId") ~= nil then
		if prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			prompt.Enabled = false
		end
	end
end

workspace.DescendantAdded:Connect(filterPrompt)
for _, descendant in workspace:GetDescendants() do
	filterPrompt(descendant)
end
