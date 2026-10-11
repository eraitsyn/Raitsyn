--!strict
-- Always-on HUD: the coin balance with a smooth count-up and $/s under it,
-- a chip with rebirths / income multiplier / luck, the left rail that opens
-- every panel, and Home / Hub teleport buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Rules = require(Shared:WaitForChild("Logic"):WaitForChild("Rules"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local State = require(Client:WaitForChild("State"))
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local Root = require(Client:WaitForChild("UI"):WaitForChild("Root"))
local Theme = require(Client:WaitForChild("UI"):WaitForChild("Theme"))

local Hud = {}

local RAIL = {
	{ id = "Inventory", icon = Theme.icon.pets, label = "Pets", colour = Theme.color.blue },
	{ id = "Farm", icon = Theme.icon.farm, label = "Farm", colour = Theme.color.green },
	{ id = "Upgrades", icon = Theme.icon.upgrades, label = "Upgrades", colour = Theme.color.purple },
	{ id = "Index", icon = Theme.icon.index, label = "Index", colour = Color3.fromRGB(255, 150, 60) },
	{ id = "Daily", icon = Theme.icon.daily, label = "Daily", colour = Color3.fromRGB(255, 110, 160) },
	{ id = "Rebirth", icon = Theme.icon.rebirth, label = "Rebirth", colour = Color3.fromRGB(190, 110, 255) },
	{ id = "Settings", icon = Theme.icon.settings, label = "Settings", colour = Theme.color.greyDark },
}

local function railButton(entry, order: number, parent: Instance): Frame
	local holder = Kit.new("Frame", {
		Name = entry.id,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(74, 74),
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.button({
		text = entry.icon,
		colour = entry.colour,
		size = UDim2.fromOffset(64, 60),
		position = UDim2.fromOffset(5, 0),
		textSize = 30,
		font = Theme.font.body,
		parent = holder,
		onClick = function()
			App.togglePanel(entry.id)
		end,
	})
	Kit.label({
		Text = entry.label,
		FontFace = Theme.font.heading,
		TextSize = 15,
		TextColor3 = Theme.color.white,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		ZIndex = 3,
		Parent = holder,
	}, true)
	local dot = Kit.new("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.color.red,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -16, 0, -4),
		Visible = false,
		ZIndex = 4,
		Parent = holder,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.color.white, 2) })
	return dot
end

function Hud.start()
	local hud = Root.hud

	-- Coins (top centre)
	local coinPill = Kit.new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(280, 54),
		BackgroundColor3 = Theme.color.panel,
		Parent = hud,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke() })
	local coinIcon = Kit.new("Frame", {
		BackgroundColor3 = Theme.color.coin,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(5, 5),
		Parent = coinPill,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.color.coinDark, 3) })
	Kit.label({
		Text = "$",
		FontFace = Theme.font.heading,
		TextSize = 28,
		TextColor3 = Theme.color.white,
		Parent = coinIcon,
	}, true)
	local coinText = Kit.label({
		Text = "$0",
		FontFace = Theme.font.heading,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(54, 0),
		Parent = coinPill,
	})
	local rateText = Kit.label({
		Text = "+$0/s",
		FontFace = Theme.font.heading,
		TextSize = 22,
		TextColor3 = Theme.color.coin,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(260, 26),
		Parent = hud,
	}, true)

	-- Count-up: the shown value eases toward the real balance every frame.
	local shown = State.data.coins
	RunService.RenderStepped:Connect(function(dt: number)
		local target = State.data.coins
		if math.abs(target - shown) < 0.5 then
			shown = target
		else
			shown += (target - shown) * math.min(1, dt * 8)
		end
		coinText.Text = Format.coins(shown)
	end)
	State.watch({ "@rate" }, function()
		rateText.Text = "+" .. Format.rate(State.rate)
	end)

	-- Stats chip
	local chip = Kit.new("Frame", {
		Name = "StatsChip",
		-- bottom right: the top corners belong to Roblox's menu and player list
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.color.panel,
		Parent = hud,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(), Kit.padding(14, 0) })
	local chipText = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 18,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Parent = chip,
	})
	State.watch({ "@stats", "rebirths" }, function()
		local stats = State.stats
		chipText.Text = string.format(
			"%s Rebirth %d    %s x%.2f    %s x%.2f",
			Theme.icon.star,
			State.data.rebirths,
			Theme.icon.coin,
			stats.incomeMultiplier,
			Theme.icon.luck,
			stats.luck
		)
	end)

	-- Left rail
	local rail = Kit.new("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 10),
		Size = UDim2.fromOffset(80, #RAIL * 80),
		BackgroundTransparency = 1,
		Parent = Root.nav,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })
	local dots: { [string]: Frame } = {}
	for i, entry in RAIL do
		dots[entry.id] = railButton(entry, i, rail)
	end

	-- Daily dot: lit while a claim is ready.
	task.spawn(function()
		while true do
			local daily = Rules.daily(State.data.daily.streak, State.data.daily.last, math.floor(State.now()))
			dots.Daily.Visible = daily.canClaim
			task.wait(1)
		end
	end)

	-- Home / Hub (right side)
	local travel = Kit.new("Frame", {
		Name = "Travel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(74, 160),
		BackgroundTransparency = 1,
		Parent = Root.nav,
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })
	-- full-screen panels (the upgrade tree) use the right edge for their own sheet
	Root.panelChanged.Event:Connect(function(panel)
		travel.Visible = not (panel and panel.fullscreen)
	end)
	for i, entry in
		{
			{ icon = Theme.icon.home, label = "Home", fn = App.teleportHome, colour = Theme.color.green },
			{ icon = Theme.icon.hub, label = "Hub", fn = App.teleportHub, colour = Theme.color.blue },
		}
	do
		local holder = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(74, 74),
			LayoutOrder = i,
			Parent = travel,
		})
		Kit.button({
			text = entry.icon,
			colour = entry.colour,
			size = UDim2.fromOffset(64, 60),
			position = UDim2.fromOffset(5, 0),
			textSize = 30,
			font = Theme.font.body,
			parent = holder,
			onClick = entry.fn,
		})
		Kit.label({
			Text = entry.label,
			FontFace = Theme.font.heading,
			TextSize = 15,
			TextColor3 = Theme.color.white,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 1, -18),
			ZIndex = 3,
			Parent = holder,
		}, true)
	end

	-- Saving status: say so plainly when this session does not save.
	if not State.saving then
		Root.toast(
			if State.studio
				then "Saving is off in this Studio test (no API access)."
				else "Saving is unavailable right now. Progress may not be kept.",
			"error"
		)
	end
end

return Hud
