--[[
	Gate: the only place remote handlers are registered, and the rate limit for
	ProximityPrompt triggers.

	Every request is rate limited per player, then type checked, before the handler
	runs. Failures are dropped silently and count as strikes; too many strikes in a
	window kicks the player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Validate = require(ReplicatedStorage.Shared.Validate)
local RateLimiter = require(script.Parent.RateLimiter)

local STRIKE_LIMIT = 20
local STRIKE_WINDOW = 60 -- seconds

export type Options = {
	rate: { capacity: number, perSecond: number },
	args: { Validate.Check },
}

local Gate = {}

local limiters: { RateLimiter.RateLimiter } = {}
local strikes: { [Player]: { count: number, since: number } } = {}

local function strike(player: Player, remoteName: string, reason: string)
	local now = os.clock()
	local record = strikes[player]
	if record == nil or now - record.since > STRIKE_WINDOW then
		record = { count = 0, since = now }
		strikes[player] = record
	end
	record.count += 1
	if record.count > STRIKE_LIMIT then
		warn(`[Gate] kicking {player.Name} ({player.UserId}): {reason} on {remoteName}`)
		strikes[player] = nil
		player:Kick("Too many invalid requests.")
	end
end

function Gate.Handle(name: string, options: Options, handler: (Player, ...any) -> ()): RBXScriptConnection
	local remote = Remotes.Get(name)
	local limiter = RateLimiter.new(options.rate.capacity, options.rate.perSecond)
	table.insert(limiters, limiter)

	return remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if player.Parent ~= Players then
			return
		end
		if not limiter:Allow(player) then
			strike(player, name, "rate limited")
			return
		end
		if not Validate.Args(options.args, ...) then
			strike(player, name, "invalid payload")
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[Gate] {name} handler failed for {player.Name}: {err}`)
		end
	end)
end

-- Prompts are triggered by clients too, so they share one rate limit per player.
local promptLimiter = RateLimiter.new(8, 4)
table.insert(limiters, promptLimiter)

-- Call first in every ProximityPrompt.Triggered handler.
function Gate.AllowPrompt(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	if not promptLimiter:Allow(player) then
		strike(player, "prompt", "rate limited")
		return false
	end
	return true
end

function Gate.Notify(player: Player, kind: string, id: string?)
	Remotes.Get("Notify"):FireClient(player, { kind = kind, id = id })
end

-- Tells every player, for example about a rare hatch. `by` is the player it is about.
function Gate.NotifyAll(kind: string, id: string?, by: Player)
	Remotes.Get("Notify"):FireAllClients({ kind = kind, id = id, by = by.DisplayName })
end

Players.PlayerRemoving:Connect(function(player)
	strikes[player] = nil
	for _, limiter in limiters do
		limiter:Forget(player)
	end
end)

return Gate
