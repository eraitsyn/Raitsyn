--[[
	Remotes: the full list of RemoteEvents this game uses.

	The server creates them at boot; clients wait for them. Server code should
	register handlers through Server.Gate, never by connecting OnServerEvent directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"RequestLock", -- client -> server: ()
	"Notify", -- server -> client: ({ kind: string, id: string? })
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
