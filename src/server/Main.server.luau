-- Server entry point. Order matters: plots and config are checked before players are handled.

local RunService = game:GetService("RunService")

local Services = script.Parent.Services

if RunService:IsStudio() then
	require(script.Parent.DevScaffold).BuildIfMissing()
end

require(Services.PlotService).Init()
require(Services.PurchaseService).Init()
require(Services.TycoonService).Init()
