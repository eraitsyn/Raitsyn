--!strict
-- Server-wide moments: another player rolling or hatching a Legendary or
-- better, or rebirthing, shows as a banner (one at a time, queued) and a
-- chat line. Your own moments already get the full reveal, so they are not
-- repeated here. Also shows the small "Critical!" pop when a farm tick crits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Pets = require(Shared:WaitForChild("Config"):WaitForChild("Pets"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))

local Client = script.Parent.Parent
local Net = require(Client:WaitForChild("Net"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))

local Announcements = {}

type Moment = {
	kind: string,
	userId: number,
	name: string,
	rarity: string?,
	species: string?,
	rebirths: number?,
}

local MAX_QUEUE = 6

local function describe(moment: Moment): (string, Color3, number)
	if moment.kind == "rebirth" then
		return `{moment.name} reached Rebirth {moment.rebirths or "?"}!`, Color3.fromRGB(190, 110, 255), 3
	end
	local rarity = Rarities.byId[moment.rarity or ""]
	if rarity == nil then
		return "", Theme.color.grey, 0
	end
	local colour = if rarity.id == Rarities.secretId then Color3.fromRGB(200, 120, 255) else rarity.color
	local seconds = if rarity.order >= 6 then 5 else 3.5
	if moment.kind == "hatch" and moment.species and Pets.byId[moment.species] then
		return `{moment.name} hatched a {rarity.name} {Pets.byId[moment.species].name}!`, colour, seconds
	end
	return `{moment.name} rolled a {rarity.name} egg!`, colour, seconds
end

local function chatLine(text: string, colour: Color3)
	-- best effort: the default chat channel may not exist (custom chat)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
		if general then
			general:DisplaySystemMessage(`<font color="#{colour:ToHex()}">{text}</font>`)
		end
	end)
end

function Announcements.start()
	local banner = Kit.new("Frame", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.color.overlay,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = Root.hud,
	}, { Kit.corner(UDim.new(1, 0)), Kit.padding(22, 0) })
	local stroke = Kit.stroke(Theme.color.white, 3) :: UIStroke
	stroke.Parent = banner
	local text = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 24,
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = banner,
	}, true)

	local queue: { Moment } = {}
	local showing = false
	local function showNext()
		if showing then
			return
		end
		showing = true
		while #queue > 0 do
			local moment = table.remove(queue, 1) :: Moment
			local line, colour, seconds = describe(moment)
			if seconds > 0 then
				text.Text = line
				text.TextColor3 = colour
				stroke.Color = colour
				banner.Visible = true
				banner.Position = UDim2.new(0.5, 0, 0, 84)
				Kit.tween(banner, 0.3, { Position = UDim2.new(0.5, 0, 0, 108) }, Enum.EasingStyle.Back)
				task.wait(seconds)
				banner.Visible = false
				task.wait(0.2)
			end
		end
		showing = false
	end

	Net.on("Rolled", function(moment: Moment)
		if type(moment) ~= "table" or moment.userId == Players.LocalPlayer.UserId then
			return
		end
		local line, colour, seconds = describe(moment)
		if seconds <= 0 then
			return
		end
		chatLine(line, colour)
		if #queue < MAX_QUEUE then
			table.insert(queue, moment)
			task.spawn(showNext)
		end
	end)

	-- A critical farm tick: a gold "+$X Critical!" that floats up under the
	-- coin counter.
	Net.on("Notice", function(notice: { kind: string, amount: number? })
		if type(notice) ~= "table" or notice.kind ~= "crit" or type(notice.amount) ~= "number" then
			return
		end
		local pop = Kit.label({
			Text = `+{Format.coins(notice.amount)} Critical!`,
			FontFace = Theme.font.heading,
			TextSize = 26,
			TextColor3 = Theme.color.coin,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, math.random(-40, 40), 0, 96),
			Size = UDim2.fromOffset(320, 32),
			Parent = Root.hud,
		}, true)
		Kit.tween(pop, 1.2, { Position = pop.Position - UDim2.fromOffset(0, 40), TextTransparency = 1 })
		local popStroke = pop:FindFirstChildOfClass("UIStroke")
		if popStroke then
			Kit.tween(popStroke, 1.2, { Transparency = 1 })
		end
		task.delay(1.25, function()
			pop:Destroy()
		end)
	end)
end

return Announcements
