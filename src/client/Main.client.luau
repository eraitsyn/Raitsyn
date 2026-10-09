--[[
	Client entry point. The client only displays state and asks the server for
	actions; it never sends prices, amounts, gods or positions. Hiding prompts
	here is for clarity only: the server checks every trigger itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GodConfig = require(ReplicatedStorage.Shared.Config.Gods)

local player = Players.LocalPlayer

local function godName(id: string?): string
	local god = id and GodConfig.Gods[id]
	return if god then god.name else "god"
end

local MESSAGES: { [string]: (id: string?) -> string } = {
	Bought = function(id)
		return `{godName(id)} joined your base!`
	end,
	Sold = function(id)
		return `Sold {godName(id)}.`
	end,
	TooPoor = function()
		return "Not enough cash."
	end,
	BaseFull = function()
		return "Your base is full. Sell a god to make room."
	end,
	Stealing = function(id)
		return `You grabbed {godName(id)}! Run back to your base!`
	end,
	BeingStolen = function(id)
		return `Someone is stealing your {godName(id)}!`
	end,
	Stole = function(id)
		return `You stole {godName(id)}!`
	end,
	WasStolen = function(id)
		return `Your {godName(id)} was stolen.`
	end,
	StealFailed = function(id)
		return `Steal failed. {godName(id)} went back.`
	end,
	StealTimedOut = function(id)
		return `Too slow! {godName(id)} went back.`
	end,
	Locked = function()
		return "That base is locked."
	end,
	LockOn = function()
		return "Base locked!"
	end,
	LockCooldown = function()
		return "Lock is recharging."
	end,
}

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHud"
gui.ResetOnSpawn = false

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 16)
toast.Size = UDim2.fromOffset(420, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui

local lockButton = Instance.new("TextButton")
lockButton.Name = "Lock"
lockButton.AnchorPoint = Vector2.new(1, 1)
lockButton.Position = UDim2.new(1, -16, 1, -16)
lockButton.Size = UDim2.fromOffset(160, 48)
lockButton.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
lockButton.TextColor3 = Color3.new(1, 1, 1)
lockButton.Font = Enum.Font.GothamBold
lockButton.TextScaled = true
lockButton.Text = "Lock Base"
lockButton.Parent = gui

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

Remotes.Get("Notify").OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.kind) ~= "string" then
		return
	end
	local format = MESSAGES[message.kind]
	if format then
		showToast(format(if type(message.id) == "string" then message.id else nil))
	end
end)

local requestLock = Remotes.Get("RequestLock")
lockButton.Activated:Connect(function()
	requestLock:FireServer()
end)

-- Lock button countdown, from the server-time attribute the server sets.
RunService.Heartbeat:Connect(function()
	local readyAt = player:GetAttribute("LockReadyAt")
	local remaining = if type(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
	if remaining > 0 then
		lockButton.Text = `Lock ({math.ceil(remaining)}s)`
		lockButton.AutoButtonColor = false
		lockButton.BackgroundTransparency = 0.5
	else
		lockButton.Text = "Lock Base"
		lockButton.AutoButtonColor = true
		lockButton.BackgroundTransparency = 0
	end
end)

-- Show Sell only on your own gods and Steal only on other players' gods.
local function filterPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local kind = prompt:GetAttribute("Kind")
	local mine = prompt:GetAttribute("OwnerUserId") == player.UserId
	if kind == "Sell" then
		prompt.Enabled = mine
	elseif kind == "Steal" then
		prompt.Enabled = not mine
	end
end

workspace.DescendantAdded:Connect(filterPrompt)
for _, descendant in workspace:GetDescendants() do
	filterPrompt(descendant)
end
