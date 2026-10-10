--[[
	Client entry point. The client only shows state; every action is a request
	the server checks (a remote through Gate, or a ProximityPrompt).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Hatch = require(script.Parent.Hatch)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local RollPanel = require(script.Parent.RollPanel)
local Ui = require(script.Parent.Ui)
require(script.Parent.World)

Hud.OnMenu = Panels.Toggle

local function stringField(message: any, field: string): string?
	local value = message[field]
	return if type(value) == "string" then value else nil
end

local function numberField(message: any, field: string): number?
	local value = message[field]
	return if type(value) == "number" and value == value then value else nil
end

local function petName(message: any): string
	local id = stringField(message, "id")
	if id == nil or PetConfig.Pets[id] == nil then
		return "a pet"
	end
	local mutation = stringField(message, "mutation")
	return PetInfo.Name(id, if mutation and PetInfo.MutationsById[mutation] then mutation else nil)
end

local function eggName(message: any): string
	local egg = PetConfig.EggsById[stringField(message, "id") or ""]
	return if egg then egg.name else "an egg"
end

-- Toast text for each message kind.
local MESSAGES: { [string]: (message: any) -> (string, Color3?) } = {
	BoughtEgg = function(message)
		return `Bought {eggName(message)}! Open Eggs to place it in a hatch slot.`, Ui.Money
	end,
	Placed = function(message)
		return `{eggName(message)} is hatching!`
	end,
	NotReady = function()
		return "This egg is not ready yet."
	end,
	ServerHatch = function(message)
		local id = stringField(message, "id")
		local pet = id and PetConfig.Pets[id]
		local rarity = if pet then pet.rarity .. " " else ""
		return `{stringField(message, "by") or "Someone"} hatched a {rarity}{petName(message)}!`,
			if pet then Ui.RarityTextColor(pet.rarity) else nil
	end,
	Sold = function(message)
		return `Sold {petName(message)}.`
	end,
	TooPoor = function()
		return "Not enough cash.", Ui.Red
	end,
	EggsFull = function()
		return "Your egg storage is full. Hatch eggs or upgrade Egg Storage.", Ui.Red
	end,
	SlotsFull = function()
		return "All hatch slots are busy. Upgrade Hatch Slots for more.", Ui.Red
	end,
	PetsFull = function()
		return "Your pet inventory is full. Sell some pets first.", Ui.Red
	end,
	EquipFull = function()
		return "All platforms are full. Unequip a pet or upgrade Pet Platforms.", Ui.Red
	end,
	UnlockInOrder = function()
		return "Unlock the biomes in order.", Ui.Red
	end,
	Unlocked = function(message)
		local biome = PetConfig.BiomesById[stringField(message, "id") or ""]
		return `{if biome then biome.name else "Biome"} unlocked! New eggs to roll.`, Ui.Gold
	end,
	Upgraded = function(message)
		local definition = PetInfo.UpgradesById[stringField(message, "id") or ""]
		return `{if definition then definition.name else "Upgrade"} upgraded!`, Ui.Gold
	end,
	OfflineEarned = function(message)
		local amount = numberField(message, "amount") or 0
		local seconds = numberField(message, "seconds") or 0
		return `While you were away ({Format.Duration(seconds)}) your pets made {Format.Cash(amount)}! Step on your Collector.`,
			Ui.Money
	end,
}

Remotes.Get("Notify").OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.kind) ~= "string" then
		return
	end
	local kind = message.kind
	if kind == "Hatched" then
		Hatch.Play(message)
		return
	elseif kind == "Rolled" then
		local eggId, biomeId = stringField(message, "id"), stringField(message, "biome")
		if eggId and biomeId then
			task.spawn(RollPanel.PlayRoll, eggId, biomeId)
		end
		return
	elseif kind == "Collected" or kind == "Sold" then
		local amount = numberField(message, "amount")
		if amount and amount > 0 then
			Hud.FloatCash(amount)
		end
		if kind == "Collected" then
			return
		end
	end
	local format = MESSAGES[kind]
	if format then
		Hud.Toast(format(message))
	end
end)
