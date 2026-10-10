-- Server entry point. Order matters: the map is checked and every service is
-- ready before players are handled.

local RunService = game:GetService("RunService")

local Services = script.Parent.Services

if RunService:IsStudio() then
	require(script.Parent.DevScaffold).BuildIfMissing()
end

require(Services.PlotService).Init()
require(Services.TycoonService).Init()
