--!strict
-- Hex tree rules: neighbours, tile state, and whether the next level can be
-- bought. Coins are checked by the server separately; this answers "is this
-- tile open to you", which the UI also uses to draw the frontier.

local Config = script.Parent.Parent.Config
local HexTree = require(Config.HexTree)
local Stats = require(script.Parent.Stats)

type Progress = Stats.Progress
type Tile = HexTree.Tile

export type TileState = "Locked" | "MilestoneLocked" | "Available" | "Owned" | "Maxed"

local DIRECTIONS = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } }

local HexGraph = {}

function HexGraph.neighbours(tileId: string): { Tile }
	local tile = HexTree.byId[tileId]
	assert(tile ~= nil, `unknown tile {tileId}`)
	local result = {}
	for _, d in DIRECTIONS do
		local other = HexTree.byCoord[`{tile.q + d[1]},{tile.r + d[2]}`]
		if other then
			table.insert(result, other)
		end
	end
	return result
end

-- Hex distance from the centre: the ring a tile sits on.
function HexGraph.ring(tile: Tile): number
	return math.max(math.abs(tile.q), math.abs(tile.r), math.abs(tile.q + tile.r))
end

-- Keystones do not open their neighbours: after a rebirth the tree must be
-- regrown from the centre even though keystones stay owned.
local function opensNeighbours(progress: Progress, tile: Tile): boolean
	return not tile.keystone and Stats.levelOf(progress, tile.id) > 0
end

function HexGraph.milestoneMet(progress: Progress, tile: Tile): (boolean, string?)
	local milestone = tile.milestone
	if milestone == nil then
		return true, nil
	end
	if milestone.rebirths and progress.rebirths < milestone.rebirths then
		return false, `Needs Rebirth {milestone.rebirths}`
	end
	if milestone.speciesFound and progress.speciesFound < milestone.speciesFound then
		return false, `Needs {milestone.speciesFound} species in your Index`
	end
	return true, nil
end

-- Whether the next level of a tile can be bought (ignoring coins).
-- Returns ok plus a short player-facing reason when not.
function HexGraph.canUpgrade(progress: Progress, tileId: string): (boolean, string?)
	local tile = HexTree.byId[tileId]
	if tile == nil or tileId == HexTree.coreId then
		return false, "Not an upgrade"
	end
	if Stats.levelOf(progress, tileId) >= tile.maxLevel then
		return false, "Fully upgraded"
	end
	local connected = false
	for _, other in HexGraph.neighbours(tileId) do
		if opensNeighbours(progress, other) then
			connected = true
			break
		end
	end
	if not connected then
		return false, "Buy a neighbouring tile first"
	end
	if tile.requires and Stats.levelOf(progress, tile.requires) < 1 then
		local required = HexTree.byId[tile.requires]
		return false, `Requires {required.name}`
	end
	return HexGraph.milestoneMet(progress, tile)
end

function HexGraph.state(progress: Progress, tileId: string): TileState
	local tile = HexTree.byId[tileId]
	assert(tile ~= nil, `unknown tile {tileId}`)
	local level = Stats.levelOf(progress, tileId)
	if level >= tile.maxLevel then
		return "Maxed"
	end
	local ok = HexGraph.canUpgrade(progress, tileId)
	if ok then
		return if level > 0 then "Owned" else "Available"
	end
	if level > 0 then
		return "Owned"
	end
	local connected = false
	for _, other in HexGraph.neighbours(tileId) do
		if opensNeighbours(progress, other) then
			connected = true
			break
		end
	end
	if connected and not HexGraph.milestoneMet(progress, tile) then
		return "MilestoneLocked"
	end
	return "Locked"
end

return HexGraph
