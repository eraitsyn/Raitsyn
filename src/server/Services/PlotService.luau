--!strict
-- Builds the world, gives each player one of the eight plots, keeps the gate
-- sign up to date, and answers "is this player standing at a station they
-- may use?" for the request handlers.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Map"))
local MapBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapBuilder"))

export type Station = "Roll" | "Hatch"

local PlotService = {}

local world: MapBuilder.World
local owners: { [number]: Player } = {}
local plotOf: { [Player]: MapBuilder.PlotHandles } = {}

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(205, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 170, 220)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.12
	grade.Contrast = 0.05
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

function PlotService.start()
	setupLighting()
	world = MapBuilder.build(workspace)
end

function PlotService.world(): MapBuilder.World
	return world
end

-- Gives the player the first free plot. Returns nil if all are taken, which
-- should never happen while the server size equals the plot count.
function PlotService.assign(player: Player): MapBuilder.PlotHandles?
	for index, plot in world.plots do
		local owner: Player? = owners[index]
		if owner == nil then
			owners[index] = player
			plotOf[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", index)
			plot.signName.Text = `{player.DisplayName}'s Farm`
			plot.signInfo.Text = ""
			plot.spawn.Enabled = true
			player.RespawnLocation = plot.spawn
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size180x180
					)
				end)
				if ok and plotOf[player] == plot then
					plot.signAvatar.Image = image
				end
			end)
			return plot
		end
	end
	return nil
end

function PlotService.release(player: Player)
	local plot = plotOf[player]
	if plot == nil then
		return
	end
	plotOf[player] = nil
	owners[plot.index] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.signName.Text = "Open plot"
	plot.signInfo.Text = ""
	plot.signAvatar.Image = ""
	plot.spawn.Enabled = false
end

function PlotService.plotOf(player: Player): MapBuilder.PlotHandles?
	return plotOf[player]
end

function PlotService.setSignInfo(player: Player, text: string)
	local plot = plotOf[player]
	if plot then
		plot.signInfo.Text = text
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Roll: your own Roll Station or anywhere on the hub Plaza.
-- Hatch: your own Hatching Platform only.
function PlotService.isNear(player: Player, station: Station): boolean
	local plot = plotOf[player]
	local position = rootPosition(player)
	if plot == nil or position == nil then
		return false
	end
	if station == "Roll" then
		if flatDistance(position, plot.rollStation.CFrame.Position) <= Map.serverStationRange then
			return true
		end
		return flatDistance(position, Map.plaza) <= Map.plazaRange + 8
	end
	return flatDistance(position, plot.hatchPlatform.CFrame.Position) <= Map.serverStationRange
end

return PlotService
