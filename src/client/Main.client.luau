--!strict
-- Client entry point: waits for the server's snapshot of your farm, then
-- starts every controller. Each controller is started in isolation so one
-- failing screen never takes the rest of the game down with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local Root = require(Client:WaitForChild("UI"):WaitForChild("Root"))
local Sfx = require(Client:WaitForChild("Sfx"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("Format"))
local Controllers = Client:WaitForChild("Controllers")

-- Patches can only arrive after the snapshot, but listen first so none is missed.
local pending: { any } = {}
local loaded = false
Net.on("Patch", function(patch)
	if loaded then
		State.applyPatch(patch)
	else
		table.insert(pending, patch)
	end
end)

local snapshot: State.Snapshot
while true do
	local response = Net.request("GetSnapshot")
	if response.ok then
		snapshot = response.data :: State.Snapshot
		break
	end
	task.wait(0.5)
end
State.load(snapshot)
loaded = true
for _, patch in pending do
	State.applyPatch(patch)
end
Sfx.start()

local ORDER = {
	"Hud",
	"Roll",
	"Hatch",
	"Inventory",
	"Farm",
	"Upgrades",
	"Index",
	"Daily",
	"Rebirth",
	"Settings",
	"Stations",
	"Announcements",
	"Effects",
	"Tutorial",
}
for _, name in ORDER do
	local module = Controllers:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, err = pcall(function()
			(require(module) :: any).start()
		end)
		if not ok then
			warn(`[Client] {name} failed to start: {err}`)
		end
	end
end

-- Welcome back: what offline earnings paid while you were away.
local offline = snapshot.offline
if offline and offline.coins > 0 then
	Root.toast(
		`Welcome back! Your farm earned {Format.coins(offline.coins)} in {Format.duration(offline.seconds)}.`,
		"good"
	)
end

-- Hand over from the loading screen.
local loading = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Loading")
if loading then
	loading:Destroy()
end
