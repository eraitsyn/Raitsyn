--!strict
-- First-session guide: four goals that teach the core loop (hatch, place,
-- roll, upgrade). A goal card sits at the bottom of the screen and a bouncing
-- marker floats over the station to visit. Each goal completes from what the
-- player actually did (read from their synced data), and progress is saved
-- so the guide never repeats. It can be skipped at any time.

local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))

local Tutorial = {}

local DONE = 99

type Goal = {
	text: string,
	done: () -> boolean,
	target: (() -> BasePart?)?,
}

local function plotPart(path: { string }): BasePart?
	local node: Instance? = App.plot()
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local GOALS: { Goal } = {
	{
		text = "Walk to your Hatchery and hatch your free egg",
		done = function()
			return State.data.stats.hatches > 0
		end,
		target = function()
			return plotPart({ "HatchPlatform", "Base" })
		end,
	},
	{
		text = "Click one of your farm pads to place your pet. It earns coins every second!",
		done = function()
			return next(State.data.placed) ~= nil
		end,
		target = function()
			return plotPart({ "Pads", "Pad1" })
		end,
	},
	{
		text = "Go to your Roll Station and roll a new egg",
		done = function()
			return State.data.stats.rolls > 0
		end,
		target = function()
			return plotPart({ "RollStation", "Base" })
		end,
	},
	{
		text = `Open {Theme.icon.upgrades} Upgrades on the left and buy your first upgrade`,
		done = function()
			return next(State.data.hex) ~= nil
		end,
	},
}

function Tutorial.start()
	if State.data.tutorial >= DONE then
		return
	end

	local card = Kit.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(560, 70),
		BackgroundColor3 = Theme.color.panel,
		Parent = Root.hud,
	}, { Kit.corner(UDim.new(0, 16)), Kit.stroke(Theme.color.coinDark, 3) })
	local stepLabel = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 16,
		TextColor3 = Theme.color.coinDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 0, 20),
		Position = UDim2.fromOffset(16, 8),
		Parent = card,
	})
	local goalLabel = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 0, 38),
		Position = UDim2.fromOffset(16, 28),
		Parent = card,
	})

	-- the marker over the current target, client-only
	local marker = Kit.new("BillboardGui", {
		Name = "TutorialMarker",
		Size = UDim2.fromOffset(80, 80),
		AlwaysOnTop = true,
		LightInfluence = 0,
		StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
		Enabled = false,
		Parent = Root.gui.Parent,
	})
	local arrow = Kit.label({
		Text = "⬇",
		TextSize = 64,
		TextColor3 = Theme.color.coin,
		Size = UDim2.fromScale(1, 1),
		Parent = marker,
	}, true)

	local step = math.max(1, State.data.tutorial + 1)
	local finished = false
	local bounce: RBXScriptConnection? = nil

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		card:Destroy()
		marker:Destroy()
		if bounce then
			bounce:Disconnect()
		end
		task.spawn(Net.request, "SetTutorial", DONE)
		if not skipped then
			Root.toast("Tutorial complete! Keep rolling for rarer pets and grow your farm.", "good")
		end
	end

	Kit.button({
		text = "Skip",
		colour = Theme.color.grey,
		size = UDim2.fromOffset(84, 44),
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		textSize = 18,
		parent = card,
		onClick = function()
			finish(true)
		end,
	})

	local function show()
		local goal = GOALS[step]
		stepLabel.Text = `GOAL {step} OF {#GOALS}`
		goalLabel.Text = goal.text
		local target = if goal.target then goal.target() else nil
		marker.Adornee = target
		marker.Enabled = target ~= nil
		if target then
			-- the offset is in the part's own axes (station bases are rotated cylinders)
			marker.StudsOffsetWorldSpace = target.CFrame:VectorToObjectSpace(Vector3.new(0, 7, 0))
		end
	end

	-- Advance past every goal already met (a returning player may have done
	-- several), saving each step so the guide resumes where it left off.
	local function check()
		if finished then
			return
		end
		local advanced = false
		while step <= #GOALS and GOALS[step].done() do
			step += 1
			advanced = true
		end
		if step > #GOALS then
			finish(false)
			return
		end
		if advanced then
			task.spawn(Net.request, "SetTutorial", step - 1)
			Kit.tween(card, 0.12, { Size = UDim2.fromOffset(580, 74) }).Completed:Once(function()
				Kit.tween(card, 0.12, { Size = UDim2.fromOffset(560, 70) })
			end)
		end
		show()
	end

	bounce = RunService.RenderStepped:Connect(function()
		arrow.Position = UDim2.fromOffset(0, math.sin(os.clock() * 4) * 8)
	end)
	State.watch({ "stats", "placed", "hex", "pets" }, check)
end

return Tutorial
