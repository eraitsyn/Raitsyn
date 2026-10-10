--[[
	DataService: loads and saves player data through ProfileStore.

	ProfileStore session-locks each profile, so a player who joins a second server
	cannot duplicate cash. It also autosaves and saves on server shutdown.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local DataSchema = require(script.Parent.Parent.DataSchema)

local STORE_NAME = "PlayerData"

local mutationsById = {}
for _, mutation in PetConfig.Mutations do
	mutationsById[mutation.id] = mutation
end
local upgradeLevels = {}
for _, definition in Economy.Upgrades do
	upgradeLevels[definition.id] = definition.maxLevel
end
local equip = PetInfo.UpgradesById.EquipSlots
local eggStorage = PetInfo.UpgradesById.EggStorage

local LIMITS: DataSchema.Limits = {
	pets = PetConfig.Pets,
	eggs = PetConfig.EggsById,
	mutations = mutationsById,
	upgrades = upgradeLevels,
	biomes = #PetConfig.Biomes,
	maxCash = Economy.MaxCash,
	maxPets = Economy.MaxPets,
	maxEggs = eggStorage.start + eggStorage.perLevel * eggStorage.maxLevel,
	hatchSlots = 8,
	equipSlots = equip.start + equip.perLevel * equip.maxLevel,
}

local store = ProfileStore.New(STORE_NAME, DataSchema.Template)
local profiles: { [Player]: any } = {}

local DataService = {}

-- Yields until the player's profile loads. Returns its data, or nil if the
-- player left or the load failed (the player is kicked in that case).
function DataService.Load(player: Player): DataSchema.PlayerData?
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Could not load your data. Please rejoin.")
		end
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	DataSchema.Sanitize(profile.Data, LIMITS)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	profiles[player] = profile
	return profile.Data
end

function DataService.Get(player: Player): DataSchema.PlayerData?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Saves and releases the session lock. Safe to call more than once.
function DataService.Release(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

return DataService
