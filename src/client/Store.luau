--[[
	Store: the latest copy of this player's state from the server, and a signal
	when it changes. The client only reads it; the server decides everything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Store = {}

Store.State = {
	unlocked = 1,
	upgrades = {},
	eggs = {},
	pets = {},
	equipped = {},
	hatching = {},
	discovered = {},
	offers = {},
	income = 0,
} :: { [string]: any }

local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

function Store.Cash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return if cash and cash:IsA("IntValue") then cash.Value else 0
end

-- The local player's lane, once the server has given them one.
function Store.Lane(): Model?
	local name = player:GetAttribute("LaneName")
	local lanes = workspace:FindFirstChild("Lanes")
	local lane = if type(name) == "string" and lanes then lanes:FindFirstChild(name) else nil
	return if lane and lane:IsA("Model") then lane else nil
end

Remotes.Get("State").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	for key, value in snapshot do
		if Store.State[key] ~= nil and type(value) == type(Store.State[key]) then
			Store.State[key] = value
		end
	end
	changed:Fire()
end)

return Store
