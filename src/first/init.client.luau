--!strict
-- Shown the moment the game starts, before anything else loads, so a player
-- never sees an empty world or a half-built UI. The client's main script
-- removes it once the farm has loaded.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(120, 196, 92)
backdrop.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(120, 196, 92))
gradient.Rotation = 90
gradient.Parent = backdrop

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromScale(0.8, 0.14)
title.Text = "Roll RNG"
title.TextScaled = true
title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = backdrop
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(40, 44, 66)
stroke.Parent = title

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.56)
status.Size = UDim2.fromScale(0.6, 0.05)
status.Text = "Loading your farm..."
status.TextScaled = true
status.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
status.TextColor3 = Color3.new(1, 1, 1)
status.Parent = backdrop

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Gentle pulse while waiting.
local t = 0
while gui.Parent do
	t += task.wait(0.05)
	status.TextTransparency = 0.25 + 0.25 * math.sin(t * 3)
end
