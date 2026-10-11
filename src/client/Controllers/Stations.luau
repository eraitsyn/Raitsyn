--!strict
-- Hub stations open their panels from ProximityPrompts. The prompts are
-- built by the server's MapBuilder; their names say which panel to open.

local ProximityPromptService = game:GetService("ProximityPromptService")

local App = require(script.Parent.Parent:WaitForChild("App"))

local Stations = {}

local PANELS: { [string]: string } = {
	OpenUpgrades = "Upgrades",
	OpenRebirth = "Rebirth",
	OpenIndex = "Index",
	OpenDaily = "Daily",
}

function Stations.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local panel = PANELS[prompt.Name]
		if panel then
			App.openPanel(panel)
		end
	end)
end

return Stations
