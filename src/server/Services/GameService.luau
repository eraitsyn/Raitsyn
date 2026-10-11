--!strict
--!nolint DeprecatedApi
-- (Player:LoadCharacter is the proven spawn call; LoadCharacterAsync can replace it after a Studio test.)
-- The glue between players and their Session: loads the profile, gives a
-- plot, registers every request handler, runs the one-second income loop and
-- streams profile changes to the owner. Game rules live in Session; this file
-- adds only what needs Roblox: who is asking, where they stand, and who to tell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))

local Server = script.Parent.Parent
local Schema = require(Server:WaitForChild("Data"):WaitForChild("Schema"))
local Session = require(Server:WaitForChild("Game"):WaitForChild("Session"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FarmService = require(script.Parent:WaitForChild("FarmService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local MapBuilder = require(Server:WaitForChild("World"):WaitForChild("MapBuilder"))

local Check = NetService.Check

-- Rarity order from which rolls and hatches are announced to the server.
local ANNOUNCE_ORDER = Rarities.byId.Legendary.order
-- Rarity order from which a hatch asks for an early save.
local EARLY_SAVE_ORDER = Rarities.byId.Mythic.order
local RESPAWN_DELAY = 3

type Dirty = { [string]: true | { [string]: true } }

type Context = {
	player: Player,
	profile: DataService.Profile,
	session: Session.Session,
	plot: MapBuilder.PlotHandles,
	dirty: Dirty,
	farmDirty: boolean,
	ready: boolean, -- the client has its snapshot; events can flow
	offline: { coins: number, seconds: number },
	leaderstats: { coins: StringValue, rebirths: IntValue },
}

local GameService = {}

local contexts: { [Player]: Context } = {}

-- Profile keys whose change means the farm visuals need a refresh.
local FARM_KEYS = {
	placed = true,
	pets = true,
	incubator = true,
	hex = true,
	keystones = true,
	rebirths = true,
	index = true,
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local random = Random.new()
local function uniform(): number
	return random:NextNumber()
end

local function markDirty(ctx: Context, key: string, sub: string?)
	if FARM_KEYS[key] then
		ctx.farmDirty = true
	end
	local entry = ctx.dirty[key]
	if entry == true then
		return
	end
	if sub == nil then
		ctx.dirty[key] = true
	else
		local subs: { [string]: true } = if entry then entry :: any else {}
		subs[sub] = true
		ctx.dirty[key] = subs
	end
end

local function renderFarm(ctx: Context)
	ctx.farmDirty = false
	local stats = ctx.session.stats
	FarmService.render(ctx.plot, {
		data = ctx.profile.Data,
		padSlots = stats.padSlots,
		incubators = stats.incubators,
		incomeMultiplier = stats.incomeMultiplier,
	})
end

-- Followers are drawn by every client, so the species and variant of each
-- pet following a player is public: "BarnChick:0,MudPiglet:1".
local function followingAttribute(data: Schema.Profile): string
	local parts = {}
	for _, petId in data.following do
		local pet = data.pets[petId]
		if pet then
			table.insert(parts, `{pet.s}:{pet.v}`)
		end
	end
	return table.concat(parts, ",")
end

local function updatePublicInfo(ctx: Context)
	local data = ctx.profile.Data
	local following = followingAttribute(data)
	if ctx.player:GetAttribute("Following") ~= following then
		ctx.player:SetAttribute("Following", following)
	end
	ctx.leaderstats.coins.Value = Format.coins(data.coins)
	ctx.leaderstats.rebirths.Value = data.rebirths
	PlotService.setSignInfo(
		ctx.player,
		if data.rebirths > 0
			then `Rebirth {data.rebirths} · {Format.rate(ctx.session.rate)}`
			else Format.rate(ctx.session.rate)
	)
end

-- Sends one batched patch per player per frame.
local function flush(ctx: Context)
	if next(ctx.dirty) == nil then
		if ctx.farmDirty then
			renderFarm(ctx)
		end
		return
	end
	local data = ctx.profile.Data :: any
	local patch = {}
	for key, entry in ctx.dirty do
		if entry == true then
			table.insert(patch, { k = key, v = data[key] })
		else
			for sub in entry :: { [string]: true } do
				table.insert(patch, { k = key, s = sub, v = data[key][sub] })
			end
		end
	end
	table.clear(ctx.dirty)
	if ctx.ready then
		NetService.fire("Patch", ctx.player, patch)
	end
	if ctx.farmDirty then
		renderFarm(ctx)
	end
	updatePublicInfo(ctx)
end

local function makeLeaderstats(player: Player): { coins: StringValue, rebirths: IntValue }
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
	return { coins = coins, rebirths = rebirths }
end

local function spawnCharacter(player: Player)
	if player.Parent ~= Players or contexts[player] == nil then
		return
	end
	player:LoadCharacter()
end

local function onPlayerAdded(player: Player)
	local profile, loadError = DataService.load(player)
	if profile == nil then
		if loadError == "future" then
			player:Kick("This server is older than your save. Please rejoin to get a newer server.")
		elseif loadError == "failed" then
			player:Kick("Your farm could not be loaded safely. Please rejoin.")
		end
		return
	end
	local plot = PlotService.assign(player)
	if plot == nil then
		profile:EndSession()
		player:Kick("This server is full. Please rejoin.")
		return
	end

	local ctx: Context
	local session = Session.new(profile.Data, {
		now = now,
		random = uniform,
		onChange = function(key, sub)
			if ctx then
				markDirty(ctx, key, sub)
			end
		end,
	})
	ctx = {
		player = player,
		profile = profile,
		session = session,
		plot = plot,
		dirty = {},
		farmDirty = true,
		ready = false,
		offline = { coins = 0, seconds = 0 },
		leaderstats = makeLeaderstats(player),
	}
	contexts[player] = ctx

	local fixes = Schema.repair(profile.Data, session.stats.padSlots, Economy.maxFollowers)
	if fixes > 0 then
		warn(`[Game] repaired {fixes} values in {player.UserId}'s profile`)
		session:_refresh()
	end
	session:grantStarter()
	local coins, seconds = session:applyOffline()
	ctx.offline = { coins = coins, seconds = seconds }

	profile.OnSave:Connect(function()
		if contexts[player] == ctx then
			session:markLogout()
		end
	end)
	profile.OnSessionEnd:Connect(function()
		if contexts[player] == ctx and player.Parent == Players then
			player:Kick("Your farm was opened on another server.")
		end
	end)

	renderFarm(ctx)
	updatePublicInfo(ctx)
	LeaderboardService.track(player, function()
		local data = profile.Data
		return { coins = data.lifetimeCoins, rebirths = data.rebirths, rarest = data.stats.rarestScore }
	end)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.delay(RESPAWN_DELAY, spawnCharacter, player)
		end)
	end)
	spawnCharacter(player)
end

local function onPlayerRemoving(player: Player)
	local ctx = contexts[player]
	if ctx == nil then
		return
	end
	contexts[player] = nil
	LeaderboardService.untrack(player)
	ctx.session:markLogout()
	ctx.profile:EndSession()
	FarmService.clear(ctx.plot)
	PlotService.release(player)
end

-- Wraps a handler so it only runs for players whose data is loaded.
local function withContext(handler: (Context, ...any) -> (any, string?)): NetService.Handler
	return function(player: Player, ...: any): (any, string?)
		local ctx = contexts[player]
		if ctx == nil then
			return nil, "Your farm is still loading"
		end
		return handler(ctx, ...)
	end
end

local function announce(player: Player, kind: string, rarityId: string, speciesId: string?)
	local rarity = Rarities.byId[rarityId]
	if rarity and rarity.order >= ANNOUNCE_ORDER then
		NetService.fireAll("Rolled", {
			kind = kind,
			userId = player.UserId,
			name = player.DisplayName,
			rarity = rarityId,
			species = speciesId,
		})
	end
end

local function registerHandlers()
	local slow = { perSecond = 2, burst = 5 }
	local normal = { perSecond = 6, burst = 12 }

	NetService.onRequest(
		"GetSnapshot",
		{ args = {}, perSecond = 1, burst = 10 },
		withContext(function(ctx)
			local firstTime = not ctx.ready
			ctx.ready = true
			table.clear(ctx.dirty) -- the snapshot already carries everything
			return {
				profile = ctx.profile.Data,
				plot = ctx.plot.index,
				serverTime = now(),
				saving = DataService.isSaving(),
				studio = DataService.isStudio(),
				offline = if firstTime then ctx.offline else nil,
				nextRollAt = ctx.session.nextRollAt,
			}
		end)
	)

	NetService.onRequest(
		"Roll",
		{ args = { Check.id }, perSecond = 3, burst = 4 },
		withContext(function(ctx, tierId: string)
			if not PlotService.isNear(ctx.player, "Roll") then
				return nil, "Walk to your Roll Station or the Plaza to roll"
			end
			local result, err = ctx.session:roll(tierId)
			if result then
				announce(ctx.player, "roll", result.rarity, nil)
			end
			return result, err
		end)
	)

	NetService.onRequest(
		"Hatch",
		{ args = { Check.optionalId, Check.int(1, 25) }, perSecond = 3, burst = 6 },
		withContext(function(ctx, rarityId: string?, count: number)
			if not PlotService.isNear(ctx.player, "Hatch") then
				return nil, "Walk to your Hatchery to hatch eggs"
			end
			return ctx.session:hatch(rarityId, count)
		end)
	)

	NetService.onRequest(
		"Place",
		{ args = { Check.id, Check.int(1, Economy.maxPadSlots) }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, petId: string, pad: number)
			return ctx.session:place(petId, pad)
		end)
	)

	NetService.onRequest(
		"Remove",
		{ args = { Check.int(1, Economy.maxPadSlots) }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, pad: number)
			return ctx.session:remove(pad)
		end)
	)

	NetService.onRequest(
		"RemoveAll",
		{ args = {}, perSecond = slow.perSecond, burst = slow.burst },
		withContext(function(ctx)
			return ctx.session:removeAll()
		end)
	)

	NetService.onRequest(
		"PlaceBest",
		{ args = {}, perSecond = slow.perSecond, burst = slow.burst },
		withContext(function(ctx)
			return ctx.session:placeBest()
		end)
	)

	NetService.onRequest(
		"SetLocked",
		{ args = { Check.id, Check.bool }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, petId: string, locked: boolean)
			return ctx.session:setLocked(petId, locked)
		end)
	)

	NetService.onRequest(
		"SetFollowing",
		{ args = { Check.id, Check.bool }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, petId: string, follow: boolean)
			return ctx.session:setFollowing(petId, follow)
		end)
	)

	NetService.onRequest(
		"Release",
		{ args = { Check.idList(100) }, perSecond = slow.perSecond, burst = slow.burst },
		withContext(function(ctx, ids: { string })
			return ctx.session:release(ids)
		end)
	)

	NetService.onRequest(
		"ReleaseRarity",
		{ args = { Check.id }, perSecond = 1, burst = 2 },
		withContext(function(ctx, rarityId: string)
			return ctx.session:releaseRarity(rarityId)
		end)
	)

	NetService.onRequest(
		"BuyTile",
		{ args = { Check.id }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, tileId: string)
			local level, err = ctx.session:buyTile(tileId)
			if level and ctx.profile.Data.keystones[tileId] then
				DataService.saveSoon(ctx.player, ctx.profile)
			end
			return level, err
		end)
	)

	NetService.onRequest(
		"Rebirth",
		{ args = {}, perSecond = 1, burst = 2 },
		withContext(function(ctx)
			local rebirths, err = ctx.session:rebirth()
			if rebirths then
				DataService.saveSoon(ctx.player, ctx.profile)
				NetService.fireAll("Rolled", {
					kind = "rebirth",
					userId = ctx.player.UserId,
					name = ctx.player.DisplayName,
					rebirths = rebirths,
				})
			end
			return rebirths, err
		end)
	)

	NetService.onRequest(
		"ClaimDaily",
		{ args = {}, perSecond = 1, burst = 3 },
		withContext(function(ctx)
			return ctx.session:claimDaily()
		end)
	)

	NetService.onRequest(
		"SetSetting",
		{ args = { Check.id, Check.settingValue }, perSecond = normal.perSecond, burst = normal.burst },
		withContext(function(ctx, key: string, value: any)
			return ctx.session:setSetting(key, value)
		end)
	)

	NetService.onRequest(
		"SetTutorial",
		{ args = { Check.int(1, 99) }, perSecond = slow.perSecond, burst = slow.burst },
		withContext(function(ctx, step: number)
			return ctx.session:setTutorial(step)
		end)
	)
end

local function tickAll()
	for player, ctx in contexts do
		if ctx.ready then
			local ok, result = pcall(ctx.session.tick, ctx.session)
			if not ok then
				warn(`[Game] tick failed for {player.UserId}: {result}`)
				continue
			end
			if result.crit then
				NetService.fire("Notice", player, { kind = "crit", amount = result.income })
			end
			if #result.hatched > 0 then
				NetService.fire("Hatched", player, result.hatched)
				for _, pet in result.hatched do
					announce(player, "hatch", pet.rarity, pet.species)
					if Rarities.byId[pet.rarity].order >= EARLY_SAVE_ORDER then
						DataService.saveSoon(player, ctx.profile)
					end
				end
			end
		end
	end
end

function GameService.start()
	Players.CharacterAutoLoads = false
	for _, plot in PlotService.world().plots do
		FarmService.clear(plot)
	end
	registerHandlers()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Studio-only testing aid: a server-side BindableFunction (clients can't
	-- reach ServerStorage) that grants coins so late-game screens can be
	-- playtested. It is never created in a live server.
	if RunService:IsStudio() then
		local grant = Instance.new("BindableFunction")
		grant.Name = "StudioGrantCoins"
		grant.OnInvoke = function(player: Player, amount: number): string
			local ctx = contexts[player]
			if ctx == nil then
				return "no session"
			end
			ctx.session:_addCoins(amount, false)
			return `coins now {ctx.session.data.coins}`
		end
		grant.Parent = game:GetService("ServerStorage")
	end

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= 1 then
			accumulated %= 1
			tickAll()
		end
		for _, ctx in contexts do
			flush(ctx)
		end
	end)
end

return GameService
