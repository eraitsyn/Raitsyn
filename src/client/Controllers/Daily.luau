--!strict
-- Daily rewards: a seven-day streak. Coin days pay minutes of your current
-- income (with a floor), so they stay useful at every stage; days 3 and 7
-- add an egg. The server decides what a claim pays; this panel previews it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Daily = require(Config:WaitForChild("Daily"))
local Format = require(Logic:WaitForChild("Format"))
local Rules = require(Logic:WaitForChild("Rules"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local DailyPanel = {}

local PINK = Color3.fromRGB(255, 110, 160)

type DayCard = { frame: Frame, stroke: UIStroke, title: TextLabel, reward: TextLabel, mark: TextLabel }

local function rewardText(day: number): string
	local reward = Daily.rewards[day]
	local parts = {}
	if reward.incomeMinutes then
		table.insert(parts, Format.coins(Rules.dailyCoins(day, State.rate)))
	end
	if reward.egg then
		table.insert(parts, `{Theme.icon.egg} {reward.egg} egg`)
	end
	return table.concat(parts, "\n+ ")
end

function DailyPanel.start()
	local panel = Kit.panel("Daily Rewards", Vector2.new(820, 420), PINK)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Daily", handle)

	Kit.label({
		Text = "Claim once a day to build your streak. Miss two days and it starts again.",
		FontFace = Theme.font.body,
		TextSize = 17,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = panel.body,
	})
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 170),
		Position = UDim2.fromOffset(0, 34),
		Parent = panel.body,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })

	local cards: { DayCard } = {}
	for day = 1, #Daily.rewards do
		local big = Daily.rewards[day].egg ~= nil
		local frame = Kit.new("Frame", {
			BackgroundColor3 = Theme.color.panelAlt,
			Size = UDim2.fromOffset(102, 170),
			LayoutOrder = day,
			Parent = row,
		}, { Kit.corner(UDim.new(0, 12)) })
		local stroke = Kit.stroke(Theme.color.panelDeep, 3) :: UIStroke
		stroke.Parent = frame
		local title = Kit.label({
			Text = `Day {day}`,
			FontFace = Theme.font.heading,
			TextSize = 20,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 6),
			Parent = frame,
		})
		Kit.label({
			Text = if big then Theme.icon.egg else Theme.icon.coin,
			TextSize = 36,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 34),
			Parent = frame,
		})
		local reward = Kit.label({
			FontFace = Theme.font.bold,
			TextSize = 15,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 52),
			Position = UDim2.fromOffset(4, 80),
			Parent = frame,
		})
		local mark = Kit.label({
			FontFace = Theme.font.heading,
			TextSize = 16,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0, 0, 1, -30),
			Parent = frame,
		})
		cards[day] = { frame = frame, stroke = stroke, title = title, reward = reward, mark = mark }
	end

	local status = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 19,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 216),
		Parent = panel.body,
	})
	local claiming = false
	local claimButton: Kit.Button
	local function refresh()
		local data = State.data.daily
		local state = Rules.daily(data.streak, data.last, math.floor(State.now()))
		-- days already claimed in this streak (none if the streak has lapsed)
		local claimedThrough = if state.canClaim and state.nextDay == 1 then 0 else data.streak
		for day, card in cards do
			card.reward.Text = rewardText(day)
			local claimed = day <= claimedThrough
			local isNext = day == state.nextDay
			card.frame.BackgroundColor3 = if claimed
				then Theme.color.green:Lerp(Color3.new(1, 1, 1), 0.75)
				elseif isNext then PINK:Lerp(Color3.new(1, 1, 1), 0.8)
				else Theme.color.panelAlt
			card.stroke.Color = if isNext then PINK elseif claimed then Theme.color.green else Theme.color.panelDeep
			card.mark.Text = if claimed then "✔ Claimed" elseif isNext and state.canClaim then "Today!" else ""
			card.mark.TextColor3 = if claimed then Theme.color.greenDark else PINK
		end
		if state.canClaim then
			status.Text = `Day {state.nextDay} is ready to claim.`
			status.TextColor3 = Theme.color.greenDark
		else
			status.Text = `Next reward in {Format.duration(state.secondsUntilClaim)}`
			status.TextColor3 = Theme.color.muted
		end
		claimButton.setEnabled(state.canClaim and not claiming)
	end

	claimButton = Kit.button({
		text = "Claim",
		colour = PINK,
		size = UDim2.fromOffset(240, 60),
		position = UDim2.new(0.5, 0, 0, 252),
		anchor = Vector2.new(0.5, 0),
		textSize = 28,
		parent = panel.body,
		onClick = function()
			if claiming then
				return
			end
			claiming = true
			refresh()
			task.spawn(function()
				local response = Net.request("ClaimDaily")
				claiming = false
				if response.ok then
					local result = response.data
					local text = `Day {result.day} claimed: {Format.coins(result.coins)}`
					if result.egg then
						text ..= ` and a {result.egg} egg`
					end
					Root.toast(text, "good")
					Fx.flash(PINK, 0.25, 0.5)
				else
					Root.toastError(response.err)
				end
				refresh()
			end)
		end,
	})

	-- the countdown ticks while the panel is open
	handle.onOpen = function()
		refresh()
		task.spawn(function()
			while panel.root.Visible do
				task.wait(1)
				if panel.root.Visible then
					refresh()
				end
			end
		end)
	end
	State.watch({ "daily", "@rate" }, function()
		if panel.root.Visible then
			refresh()
		end
	end)
end

return DailyPanel
