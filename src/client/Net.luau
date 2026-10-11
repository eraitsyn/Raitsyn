--!strict
-- Client side of the remotes: request() invokes a server handler and always
-- returns a Response (a failed invoke becomes ok = false with a message), and
-- on() listens to a server event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))

export type Response = Remotes.Response

local Net = {}

local folder = ReplicatedStorage:WaitForChild(Remotes.folderName)

-- Yields until the server answers.
function Net.request(name: string, ...: any): Response
	local remote = folder:WaitForChild(name) :: RemoteFunction
	local ok, response = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(response) ~= "table" then
		return { ok = false, err = "Connection problem, please try again" }
	end
	return response :: Response
end

function Net.on(name: string, fn: (any) -> ()): RBXScriptConnection
	local remote = folder:WaitForChild(name) :: RemoteEvent
	return remote.OnClientEvent:Connect(fn)
end

return Net
