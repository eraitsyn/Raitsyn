--!strict
-- Screen-level effects shared by the roll and hatch reveals: a coloured
-- flash, an edge glow, camera shake and a big title. Effects scale with
-- rarity so common results stay quick and rare ones get a moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rarities"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local Root = require(Client:WaitForChild("UI"):WaitForChild("Root"))
local Theme = require(Client:WaitForChild("UI"):WaitForChild("Theme"))
local Sfx = require(Client:WaitForChild("Sfx"))

local Fx = {}

-- Reveal length in seconds per rarity order (Common .. Secret).
Fx.revealSeconds = { 1, 1, 1.5, 2, 2.5, 3.5, 5 }

function Fx.order(rarityId: string): number
	local rarity = Rarities.byId[rarityId]
	return if rarity then rarity.order else 1
end

function Fx.flash(colour: Color3, strength: number, seconds: number)
	local flash = Kit.new("Frame", {
		Name = "Flash",
		BackgroundColor3 = colour,
		BackgroundTransparency = 1 - strength,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = Root.reveal,
	})
	Kit.tween(flash, seconds, { BackgroundTransparency = 1 })
	task.delay(seconds, function()
		flash:Destroy()
	end)
end

-- A glow around the screen edges, for Epic and up.
function Fx.edgeGlow(colour: Color3, seconds: number)
	local glow = Kit.new("Frame", {
		Name = "EdgeGlow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = Root.reveal,
	})
	local stroke = Kit.new("UIStroke", {
		Color = colour,
		Thickness = 26,
		Transparency = 0.15,
		Parent = glow,
	})
	Kit.tween(stroke, seconds, { Transparency = 1 }, Enum.EasingStyle.Sine)
	task.delay(seconds, function()
		glow:Destroy()
	end)
end

function Fx.shake(intensity: number, seconds: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	-- Runs right after the camera scripts so the offset never accumulates.
	local name = `Shake{os.clock()}`
	local elapsed = 0
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function(dt)
		elapsed += dt
		if elapsed >= seconds then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local falloff = 1 - elapsed / seconds
		local x = math.noise(elapsed * 25, 0.5) * 2 * intensity * falloff
		local y = math.noise(0.5, elapsed * 25) * 2 * intensity * falloff
		camera.CFrame *= CFrame.Angles(math.rad(y), math.rad(x), 0)
	end)
end

-- Big centred title, e.g. "LEGENDARY EGG!".
function Fx.title(text: string, colour: Color3, seconds: number, y: number?)
	local label = Kit.label({
		Text = text,
		FontFace = Theme.font.heading,
		TextSize = 64,
		TextColor3 = colour,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y or 0.3),
		Size = UDim2.fromOffset(900, 90),
		ZIndex = 5,
		Parent = Root.reveal,
	}, true)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 4
	end
	local scale = Kit.new("UIScale", { Scale = 0.4, Parent = label })
	Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(seconds, function()
		Kit.tween(label, 0.3, { TextTransparency = 1 })
		if stroke then
			Kit.tween(stroke, 0.3, { Transparency = 1 })
		end
		task.wait(0.3)
		label:Destroy()
	end)
end

-- The rarity-scaled celebration for a roll or hatch result.
function Fx.celebrate(rarityId: string)
	local order = Fx.order(rarityId)
	local colour = Theme.rarity(rarityId)
	if rarityId == Rarities.secretId then
		colour = Color3.fromRGB(200, 120, 255)
	end
	Sfx.play(if order >= 5 then "big" else "reveal", 1 + 0.05 * (order - 1))
	if order >= 3 then
		Fx.flash(colour, 0.15 + 0.05 * order, 0.4 + 0.1 * order)
	end
	if order >= 4 then
		Fx.edgeGlow(colour, 1 + 0.3 * order)
	end
	if order >= 5 then
		Fx.shake(0.4 + 0.15 * (order - 5), 0.6 + 0.2 * (order - 5))
	end
	if order >= 6 then
		Fx.flash(Color3.new(1, 1, 1), 0.6, 0.9)
	end
end

return Fx
