--[[
	Ui: small helpers for building the screens in code, in one consistent style.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Dark = Color3.fromRGB(28, 26, 44)
Ui.Panel = Color3.fromRGB(44, 40, 70)
Ui.Green = Color3.fromRGB(60, 200, 90)
Ui.Red = Color3.fromRGB(230, 70, 70)
Ui.Blue = Color3.fromRGB(60, 140, 240)
Ui.Gold = Color3.fromRGB(255, 200, 60)
Ui.Gray = Color3.fromRGB(110, 110, 125)
Ui.Money = Color3.fromRGB(120, 255, 120)

function Ui.Rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

Ui.RarityColor = {} :: { [string]: Color3 }
for _, rarity in PetConfig.Rarities do
	Ui.RarityColor[rarity.name] = Ui.Rgb(rarity.color)
end

-- Secret is black, which is unreadable on dark panels; text uses red for it.
function Ui.RarityTextColor(rarity: string): Color3
	return if rarity == "Secret" then Color3.fromRGB(255, 60, 60) else Ui.RarityColor[rarity]
end

function Ui.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
end

function Ui.Stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Ui.Frame(name: string, parent: Instance, color: Color3?, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or Ui.Panel
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function Ui.Label(name: string, parent: Instance, text: string?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Ui.Font
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text or ""
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = label
	return label
end

-- A rounded, colored button that squishes when pressed.
function Ui.Button(name: string, parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.Font = Ui.Font
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	Ui.Corner(button, 10)
	Ui.Stroke(button, 2.5)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 1.5
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = button
	button.Activated:Connect(function()
		Ui.Pop(button)
		onClick()
	end)
	return button
end

-- A quick bounce, for feedback on presses and new values.
function Ui.Pop(guiObject: GuiObject)
	local scale = guiObject:FindFirstChild("PopScale") :: UIScale?
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Name = "PopScale"
		created.Parent = guiObject
		scale = created
	end
	local uiScale = scale :: UIScale
	uiScale.Scale = 0.9
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function Ui.List(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
end

-- A scrolling area that grows with its content.
function Ui.Scroll(name: string, parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	return scroll
end

-- The ScreenGui every screen lives in.
local gui = Instance.new("ScreenGui")
gui.Name = "EggRng"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
Ui.Gui = gui

return Ui
