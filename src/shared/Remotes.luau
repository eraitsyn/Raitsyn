--[[
	Remotes: the full list of RemoteEvents this game uses.

	The server creates them at boot; clients wait for them. Server code should
	register any client-to-server remote through Server.Gate, never by connecting
	OnServerEvent directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Notify", -- server -> client: ({ kind: string, id: string?, ... })
	"State", -- server -> client: the player's own inventory, pets, upgrades and offers
	"Roll", -- client -> server: (biomeId) roll a new egg offer at that biome's station
	"Buy", -- client -> server: (biomeId) buy the egg on offer there
	"PlaceEgg", -- client -> server: (eggId) put an egg from the inventory in a free hatch slot
	"Equip", -- client -> server: (petUid)
	"Unequip", -- client -> server: (petUid)
	"EquipBest", -- client -> server: ()
	"Sell", -- client -> server: (petUid)
	"Upgrade", -- client -> server: (upgradeId)
	"Teleport", -- client -> server: (biomeId or "Base")
}

local Remotes = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		folder = created
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(NAMES, name), `Unknown remote {name}`)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

return Remotes
