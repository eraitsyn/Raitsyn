--!strict
-- Creates every remote and guards every request. A request handler only
-- runs after its arguments pass their shape checks and the player is inside
-- their rate limit; anything else is answered with a refusal and counted.
-- Handlers return (data, err) and must not yield.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Validate = require(Shared:WaitForChild("Logic"):WaitForChild("Validate"))

export type Check = (value: any) -> boolean
export type Handler = (player: Player, ...any) -> (any, string?)
export type Spec = {
	args: { Check },
	perSecond: number, -- sustained rate
	burst: number, -- short bursts allowed above the rate
}

type Bucket = { tokens: number, last: number }

local NetService = {}

local folder: Folder
local functions: { [string]: RemoteFunction } = {}
local events: { [string]: RemoteEvent } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local violations: { [Player]: number } = {}

-- Argument checks shared by the handlers.
NetService.Check = {
	id = function(value: any): boolean
		return Validate.id(value, 40)
	end,
	optionalId = function(value: any): boolean
		return value == nil or Validate.id(value, 40)
	end,
	bool = function(value: any): boolean
		return Validate.boolean(value)
	end,
	int = function(min: number, max: number): Check
		return function(value: any): boolean
			return Validate.integer(value, min, max)
		end
	end,
	idList = function(maxCount: number): Check
		return function(value: any): boolean
			return Validate.idList(value, maxCount)
		end
	end,
	settingValue = function(value: any): boolean
		if type(value) == "boolean" then
			return true
		end
		return type(value) == "number" and value == value and math.abs(value) <= 1e6
	end,
}

local function refuse(player: Player, name: string, reason: string): Remotes.Response
	local count = (violations[player] or 0) + 1
	violations[player] = count
	if count <= 5 or count % 50 == 0 then
		warn(`[Net] refused {name} from {player.Name} ({player.UserId}): {reason} (total {count})`)
	end
	return { ok = false, err = "Request refused" }
end

local function takeToken(player: Player, name: string, spec: Spec): boolean
	local perPlayer = buckets[player]
	if perPlayer == nil then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if bucket == nil then
		bucket = { tokens = spec.burst, last = now }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(spec.burst, bucket.tokens + (now - bucket.last) * spec.perSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function NetService.start()
	folder = Instance.new("Folder")
	folder.Name = Remotes.folderName
	for _, name in Remotes.requests do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		functions[name] = remote
		-- Until a handler is registered, refuse rather than leave the client hanging.
		remote.OnServerInvoke = function()
			return { ok = false, err = "Not available" }
		end
	end
	for _, name in Remotes.events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		events[name] = remote
		-- Clients never send on these; ignore anything that arrives.
		remote.OnServerEvent:Connect(function(player)
			refuse(player, name, "client fired a server-only event")
		end)
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		violations[player] = nil
	end)
end

function NetService.onRequest(name: string, spec: Spec, handler: Handler)
	local remote: RemoteFunction? = functions[name]
	assert(remote, `unknown request {name}`)
	remote.OnServerInvoke = function(player: Player, ...: any): Remotes.Response
		local count = select("#", ...)
		if count > #spec.args then
			return refuse(player, name, `too many arguments ({count})`)
		end
		-- The token comes first so malformed spam is throttled too.
		if not takeToken(player, name, spec) then
			return { ok = false, err = "Slow down a little" }
		end
		local args = { ... }
		for index, check in spec.args do
			if not check(args[index]) then
				return refuse(player, name, `bad argument {index}`)
			end
		end
		local ok, data, err = pcall(handler, player, table.unpack(args, 1, #spec.args))
		if not ok then
			warn(`[Net] {name} failed for {player.Name}: {data}`)
			return { ok = false, err = "Something went wrong, please try again" }
		end
		if err ~= nil then
			return { ok = false, err = err }
		end
		return { ok = true, data = data }
	end
end

function NetService.fire(name: string, player: Player, payload: any)
	local remote: RemoteEvent? = events[name]
	assert(remote, `unknown event {name}`)
	remote:FireClient(player, payload)
end

function NetService.fireAll(name: string, payload: any)
	local remote: RemoteEvent? = events[name]
	assert(remote, `unknown event {name}`)
	remote:FireAllClients(payload)
end

return NetService
