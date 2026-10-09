--[[
	Client entry point. The client only displays state and asks the server for
	actions by name; it never sends prices, amounts or positions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local MESSAGES = {
	Purchased = "Purchased!",
	TooPoor = "Not enough cash.",
	Locked = "Buy the previous item first.",
	Owned = "You already own that.",
	TooFar = "Move closer to the button.",
	Busy = "One purchase at a time.",
	Rebirthed = "Rebirthed! Income boosted.",
	Error = "Something went wrong. Try again.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHud"
gui.ResetOnSpawn = false

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 16)
toast.Size = UDim2.fromOffset(320, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui

local rebirth = Instance.new("TextButton")
rebirth.Name = "Rebirth"
rebirth.AnchorPoint = Vector2.new(1, 1)
rebirth.Position = UDim2.new(1, -16, 1, -16)
rebirth.Size = UDim2.fromOffset(140, 44)
rebirth.Text = "Rebirth"
rebirth.TextScaled = true
rebirth.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local toastSerial = 0
local function showToast(text: string)
	toastSerial += 1
	local serial = toastSerial
	toast.Text = text
	toast.Visible = true
	task.delay(2, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

Remotes.Get("Notify").OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	local text = MESSAGES[message.kind]
	if text then
		showToast(text)
	end
end)

local requestRebirth = Remotes.Get("RequestRebirth")
rebirth.Activated:Connect(function()
	requestRebirth:FireServer()
end)
