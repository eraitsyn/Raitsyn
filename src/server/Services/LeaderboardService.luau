--!strict
-- Global leaderboards on the three hub boards: Richest (lifetime coins),
-- Most Rebirths and Rarest Pet (the best rarity score ever hatched).
--
-- Scores go to OrderedDataStores every few minutes and when a player leaves,
-- only when they changed. Top lists are read once a minute per board. When
-- DataStores are unavailable (an unpublished place, or Studio without API
-- access) the boards show this server's players instead, and say so.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("Format"))

local LeaderboardService = {}

export type Scores = { coins: number, rebirths: number, rarest: number }
type Board = {
	id: string,
	title: string,
	accent: Color3,
	store: string,
	score: (Scores) -> number,
	format: (number) -> string,
}

local WRITE_EVERY = 180
local READ_EVERY = 60
local TOP = 8
local MAX_SCORE = 2 ^ 53 - 1

local BOARDS: { Board } = {
	{
		id = "coins",
		title = "💰 Richest",
		accent = Color3.fromRGB(255, 200, 40),
		store = "RollRNG_LB_Coins_v1",
		score = function(s)
			return s.coins
		end,
		format = Format.coins,
	},
	{
		id = "rebirths",
		title = "♻️ Most Rebirths",
		accent = Color3.fromRGB(190, 110, 255),
		store = "RollRNG_LB_Rebirths_v1",
		score = function(s)
			return s.rebirths
		end,
		format = function(value)
			return Format.commas(value)
		end,
	},
	{
		id = "rarest",
		title = "🍀 Rarest Pet",
		accent = Color3.fromRGB(88, 204, 104),
		store = "RollRNG_LB_Rarest_v1",
		score = function(s)
			return s.rarest
		end,
		-- the score is 100 x log10(1 / chance), so it converts back to odds
		format = function(value)
			if value <= 0 then
				return "-"
			end
			return "1 in " .. Format.number(10 ^ (value / 100))
		end,
	},
}

type Tracked = { scores: () -> Scores, written: { [string]: number } }
local tracked: { [Player]: Tracked } = {}
local names: { [number]: string } = {}

local function clampScore(value: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_SCORE)
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and type(name) == "string" then name else `Player {userId}`
	names[userId] = result
	return result
end

local function write(player: Player, entry: Tracked)
	local ok, scores = pcall(entry.scores)
	if not ok then
		return
	end
	for _, board in BOARDS do
		local value = clampScore(board.score(scores))
		if entry.written[board.id] ~= value then
			local stored = pcall(function()
				DataStoreService:GetOrderedDataStore(board.store):SetAsync(tostring(player.UserId), value)
			end)
			if stored then
				entry.written[board.id] = value
			end
		end
	end
end

-- Starts tracking a player's scores. `scores` is read whenever a write is due.
function LeaderboardService.track(player: Player, scores: () -> Scores)
	names[player.UserId] = player.DisplayName
	tracked[player] = { scores = scores, written = {} }
end

-- Writes the player's final scores and stops tracking them.
function LeaderboardService.untrack(player: Player)
	local entry = tracked[player]
	tracked[player] = nil
	if entry then
		task.spawn(write, player, entry)
	end
end

--------------------------------------------------------------------------------
-- Board rendering

type View = { note: TextLabel, rows: { { rank: TextLabel, name: TextLabel, value: TextLabel } } }

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	text.TextScaled = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function buildView(screen: BasePart, board: Board): View
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30 -- a 16 x 20 stud board is 480 x 600 pixels
	gui.LightInfluence = 0
	gui.Parent = screen
	label(gui, {
		Text = board.title,
		FontFace = Font.fromEnum(Enum.Font.FredokaOne),
		TextColor3 = board.accent,
		Size = UDim2.new(1, -30, 0, 70),
		Position = UDim2.fromOffset(15, 10),
	})
	local note = label(gui, {
		Text = "Loading...",
		TextColor3 = Color3.fromRGB(190, 196, 214),
		Size = UDim2.new(1, -30, 0, 26),
		Position = UDim2.fromOffset(15, 84),
	})
	local rows = {}
	for i = 1, TOP do
		local y = 122 + (i - 1) * 58
		local colour = if i == 1
			then Color3.fromRGB(255, 215, 80)
			elseif i == 2 then Color3.fromRGB(220, 226, 240)
			elseif i == 3 then Color3.fromRGB(230, 160, 100)
			else Color3.new(1, 1, 1)
		rows[i] = {
			rank = label(gui, {
				Text = `#{i}`,
				TextColor3 = colour,
				Size = UDim2.fromOffset(56, 46),
				Position = UDim2.fromOffset(15, y),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			name = label(gui, {
				Text = "",
				Size = UDim2.new(0.55, -60, 0, 46),
				Position = UDim2.fromOffset(76, y),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			value = label(gui, {
				Text = "",
				TextColor3 = board.accent,
				Size = UDim2.new(0.45, -25, 0, 46),
				Position = UDim2.new(0.55, 10, 0, y),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end
	return { note = note, rows = rows }
end

local function show(view: View, board: Board, entries: { { userId: number, value: number } }, note: string)
	view.note.Text = note
	for i, row in view.rows do
		local entry = entries[i]
		row.rank.Visible = entry ~= nil
		row.name.Text = if entry then nameOf(entry.userId) else ""
		row.value.Text = if entry then board.format(entry.value) else ""
	end
end

local function readTop(board: Board): { { userId: number, value: number } }?
	local ok, result = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(board.store):GetSortedAsync(false, TOP, 1)
		local entries = {}
		for _, item in pages:GetCurrentPage() do
			local userId = tonumber(item.key)
			if userId then
				table.insert(entries, { userId = userId, value = item.value })
			end
		end
		return entries
	end)
	return if ok then result else nil
end

-- This server's players, for when the global lists cannot be read.
local function localTop(board: Board): { { userId: number, value: number } }
	local entries = {}
	for player, entry in tracked do
		local ok, scores = pcall(entry.scores)
		if ok then
			table.insert(entries, { userId = player.UserId, value = clampScore(board.score(scores)) })
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

function LeaderboardService.start(screens: { BasePart })
	local views: { View } = {}
	for i, board in BOARDS do
		local screen = screens[i]
		if screen then
			views[i] = buildView(screen, board)
		end
	end

	local function refresh()
		for i, board in BOARDS do
			local view = views[i]
			if view then
				local top = readTop(board)
				if top then
					show(view, board, top, "All players · updates every minute")
				else
					show(view, board, localTop(board), "This server (global boards need the published game)")
				end
			end
		end
	end

	task.spawn(function()
		while true do
			local ok: boolean, err: any = pcall(refresh)
			if not ok then
				warn(`[Leaderboard] refresh failed: {err}`)
			end
			task.wait(READ_EVERY)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WRITE_EVERY)
			-- writes yield, so walk a copy: players join and leave meanwhile
			for player, entry in table.clone(tracked) do
				if tracked[player] == entry then
					write(player, entry)
				end
			end
		end
	end)
	game:BindToClose(function()
		for player, entry in table.clone(tracked) do
			task.spawn(write, player, entry)
		end
		task.wait(2)
	end)
end

return LeaderboardService
