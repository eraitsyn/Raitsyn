--!strict
-- Shared client services that controllers use to talk to each other without
-- requiring one another: named panels, the local player's plot, and
-- station proximity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Map"))
local Root = require(script.Parent:WaitForChild("UI"):WaitForChild("Root"))
local State = require(script.Parent:WaitForChild("State"))

local App = {}

local player = Players.LocalPlayer
local panels: { [string]: Root.PanelHandle } = {}

function App.registerPanel(name: string, handle: Root.PanelHandle)
	panels[name] = handle
end

function App.togglePanel(name: string)
	local panel = panels[name]
	if panel then
		Root.togglePanel(panel)
	end
end

function App.openPanel(name: string)
	local panel = panels[name]
	if panel then
		Root.openPanel(panel)
	end
end

function App.closePanel()
	Root.closePanel()
end

-- The local player's plot model in the world, once assigned.
function App.plot(): Model?
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	if plots == nil then
		return nil
	end
	return plots:FindFirstChild(`Plot{State.plotIndex}`) :: Model?
end

function App.rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function stationPart(name: string): BasePart?
	local plot = App.plot()
	local station = plot and plot:FindFirstChild(name)
	return station and station:FindFirstChild("Base") :: BasePart?
end

-- Where the player can roll right now: "plot", "plaza" or nil.
function App.rollSpot(): string?
	local position = App.rootPosition()
	if position == nil then
		return nil
	end
	local station = stationPart("RollStation")
	if station and flatDistance(position, station.Position) <= Map.stationRange then
		return "plot"
	end
	if flatDistance(position, Map.plaza) <= Map.plazaRange then
		return "plaza"
	end
	return nil
end

function App.nearHatchery(): boolean
	local position = App.rootPosition()
	local station = stationPart("HatchPlatform")
	return position ~= nil and station ~= nil and flatDistance(position, station.Position) <= Map.stationRange
end

-- Moves the character (its position is client-owned, as with walking).
function App.teleport(target: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(target + Vector3.new(0, 3, 0))
	end
end

function App.teleportHome()
	local plot = App.plot()
	local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart?
	if spawn then
		App.teleport(spawn.CFrame)
	end
end

function App.teleportHub()
	-- on the plaza between two tier pillars, facing the machine
	local at = Vector3.new(0, 0, Map.plazaRadius - 5)
	App.teleport(CFrame.lookAt(at, Vector3.zero))
end

return App
