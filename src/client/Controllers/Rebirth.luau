--!strict
-- Rebirth: spend a lot of coins to start the farm over for a permanent
-- income and luck multiplier. The panel spells out exactly what you lose,
-- keep and gain, and the button must be held for 1.5 seconds so a rebirth
-- never happens by accident.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Costs = require(Logic:WaitForChild("Costs"))
local Economy = require(Config:WaitForChild("Economy"))
local Format = require(Logic:WaitForChild("Format"))
local HexTree = require(Config:WaitForChild("HexTree"))
local RollTiers = require(Config:WaitForChild("RollTiers"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local Rebirth = {}

local HOLD_SECONDS = 1.5
local ACCENT = Color3.fromRGB(170, 96, 240)

local function multiplier(value: number): string
	return "x" .. (string.gsub(string.format("%.2f", value), "%.?0+$", ""))
end

-- What reaching rebirth `n` unlocks: roll tiers and milestone tiles.
local function unlocksAt(n: number): { string }
	local names = {}
	for _, tier in RollTiers.list do
		if tier.unlockRebirths == n then
			table.insert(names, tier.name)
		end
	end
	for _, tile in HexTree.tiles do
		if tile.milestone and tile.milestone.rebirths == n then
			table.insert(names, `{tile.name} tile`)
		end
	end
	return names
end

local function column(parent: Instance, order: number, title: string, colour: Color3): TextLabel
	local box = Kit.new("Frame", {
		BackgroundColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.85),
		Size = UDim2.new(1 / 3, -8, 1, 0),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(colour, 2), Kit.padding(10) })
	Kit.label({
		Text = title,
		FontFace = Theme.font.heading,
		TextSize = 22,
		TextColor3 = Theme.shade(colour, 0.2),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = box,
	})
	return Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 16,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -32),
		Position = UDim2.fromOffset(0, 32),
		Parent = box,
	})
end

function Rebirth.start()
	local panel = Kit.panel("Rebirth", Vector2.new(780, 500), ACCENT)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Rebirth", handle)

	local headline = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = panel.body,
	})
	local progress = Kit.progress(Theme.color.coin, UDim2.new(1, 0, 0, 22), panel.body)
	progress.root.Position = UDim2.fromOffset(0, 36)
	local progressText = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = progress.root,
	})

	local columns = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 220),
		Position = UDim2.fromOffset(0, 70),
		Parent = panel.body,
	}, { Kit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })
	local loseText = column(columns, 1, "You lose", Theme.color.red)
	local keepText = column(columns, 2, "You keep", Theme.color.blue)
	local gainText = column(columns, 3, "You gain", Theme.color.green)

	-- The hold-to-confirm button: a fill sweeps across while it is held.
	local holdButton = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 304),
		Size = UDim2.fromOffset(340, 64),
		BackgroundColor3 = Theme.shade(ACCENT, 0.25),
		ClipsDescendants = true,
		Parent = panel.body,
	}, { Kit.corner(), Kit.stroke(Theme.shade(ACCENT, 0.5), 2) })
	local holdFill = Kit.new("Frame", {
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = holdButton,
	})
	local holdLabel = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 26,
		TextColor3 = Theme.color.white,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holdButton,
	}, true)
	local note = Kit.label({
		FontFace = Theme.font.body,
		TextSize = 15,
		TextColor3 = Theme.color.muted,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 374),
		Parent = panel.body,
	})

	local affordable = false
	local busy = false
	local function refresh()
		local data = State.data
		local cost = Costs.rebirthCost(data.rebirths)
		local next = data.rebirths + 1
		affordable = data.coins >= cost
		headline.Text = `Rebirth {next} costs {Format.coins(cost)}`
		progress.set(data.coins / cost)
		progressText.Text = `{Format.coins(math.min(data.coins, cost))} / {Format.coins(cost)}`

		local hexCount = 0
		for _, level in data.hex do
			hexCount += level
		end
		local placedCount = 0
		for _ in data.placed do
			placedCount += 1
		end
		loseText.Text = table.concat({
			`• All coins (back to {Format.coins(Economy.startingCoins)})`,
			`• Hex upgrades ({hexCount} levels)`,
			`• Pets on pads ({placedCount}) go back to storage`,
		}, "\n")
		keepText.Text = table.concat({
			`• Every pet ({State.petCount()})`,
			`• Eggs in storage ({State.eggTotal()})`,
			"• Your Pet Index",
			"• Milestone (keystone) tiles",
		}, "\n")

		local rebirthIncome = Economy.rebirth.incomePerRebirth
		local rebirthLuck = Economy.rebirth.luckPerRebirth
		local gains = {
			`• Income {multiplier(1 + rebirthIncome * data.rebirths)} → <b>{multiplier(1 + rebirthIncome * next)}</b>`,
			`• Luck {multiplier(1 + rebirthLuck * data.rebirths)} → <b>{multiplier(1 + rebirthLuck * next)}</b>`,
		}
		for _, name in unlocksAt(next) do
			table.insert(gains, `• Unlocks {name}`)
		end
		gainText.Text = table.concat(gains, "\n")

		holdButton.BackgroundColor3 = if affordable then Theme.shade(ACCENT, 0.25) else Theme.color.grey
		holdLabel.Text = if affordable then "Hold to Rebirth" else `Need {Format.coins(cost - data.coins)} more`
		note.Text = if affordable
			then "Hold the button for 1.5 seconds. This cannot be undone."
			else "Keep upgrading and farming: rebirth is a long-term goal."
	end

	local holding: RBXScriptConnection? = nil
	local function stopHold()
		if holding then
			holding:Disconnect()
			holding = nil
		end
		Kit.tween(holdFill, 0.2, { Size = UDim2.fromScale(0, 1) })
	end
	local function startHold()
		if not affordable or busy or holding then
			return
		end
		local held = 0
		holding = RunService.RenderStepped:Connect(function(dt: number)
			held += dt
			holdFill.Size = UDim2.fromScale(math.min(1, held / HOLD_SECONDS), 1)
			if held >= HOLD_SECONDS then
				stopHold()
				busy = true
				task.spawn(function()
					local response = Net.request("Rebirth")
					busy = false
					if response.ok then
						Root.closePanel()
						Fx.flash(Color3.new(1, 1, 1), 0.8, 1.2)
						Fx.title(`Rebirth {response.data}!`, ACCENT, 2.5)
						Fx.shake(0.6, 0.8)
					else
						Root.toastError(response.err)
					end
				end)
			end
		end)
	end
	holdButton.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			startHold()
		end
	end)
	holdButton.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stopHold()
		end
	end)
	holdButton.MouseLeave:Connect(stopHold)

	handle.onOpen = refresh
	handle.onClose = stopHold
	State.watch({ "coins", "rebirths", "hex", "placed", "pets", "eggs" }, function()
		if panel.root.Visible then
			refresh()
		end
	end)
end

return Rebirth
