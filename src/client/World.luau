--[[
	World: things the client draws in the 3D world. Egg countdowns, rainbow and
	glitch colors on rare pets, hiding other players' prompts, and opening your
	own unlocked gates (your character moves on your client, so only you can
	walk through them; the server still refuses anything in a locked biome).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Format = require(game:GetService("ReplicatedStorage").Shared.Format)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer

local EGG_TAG = "IncubatingEgg"
local RAINBOW_TAG = "RainbowPart"
local GLITCH_TAG = "GlitchPart"

local World = {}

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, shell in CollectionService:GetTagged(EGG_TAG) do
		local readyAt = shell:GetAttribute("ReadyAt")
		local tag = shell:FindFirstChild("EggTag")
		local line = tag and tag:FindFirstChild("Line2")
		if type(readyAt) == "number" and line and line:IsA("TextLabel") then
			local remaining = readyAt - now
			line.Text = if remaining > 0 then Format.Duration(remaining) else "READY! Open it"
		end
	end

	local clock = os.clock()
	local hue = (clock * 0.25) % 1
	for _, part in CollectionService:GetTagged(RAINBOW_TAG) do
		if part:IsA("BasePart") then
			part.Color = Color3.fromHSV(hue, 0.8, 1)
		end
	end
	local glitchOn = (clock * 6) % 1 < 0.15
	for _, part in CollectionService:GetTagged(GLITCH_TAG) do
		if part:IsA("BasePart") then
			part.Color = if glitchOn then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(20, 20, 25)
		end
	end
end)

-- Prompts: only show your own lane's prompts ------------------------------------

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

-- Gates -------------------------------------------------------------------------

local function refreshGates()
	local lane = Store.Lane()
	local biomes = lane and lane:FindFirstChild("Biomes")
	if biomes == nil then
		return
	end
	for _, folder in biomes:GetChildren() do
		local gate = folder:FindFirstChild("Gate")
		if gate and gate:IsA("BasePart") then
			local open = gate:GetAttribute("Unlocked") == true
			gate.CanCollide = not open
			gate.LocalTransparencyModifier = if open then 1 else 0
			local tag = gate:FindFirstChild("GateTag")
			if tag and tag:IsA("BillboardGui") then
				tag.Enabled = not open
			end
		end
	end
end

Store.Changed:Connect(refreshGates)
player:GetAttributeChangedSignal("Unlocked"):Connect(refreshGates)
player:GetAttributeChangedSignal("LaneName"):Connect(refreshGates)

return World
