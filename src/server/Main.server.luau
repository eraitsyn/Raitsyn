-- Server entry point. Order matters: the map is built and checked, and every
-- remote is registered, before players are handled.

local Services = script.Parent.Services

require(script.Parent.MapBuilder).BuildIfMissing()

require(Services.PlotService).Init()
require(Services.PetService).Init()
require(Services.HatchService).Init()
require(Services.RollService).Init()
require(Services.BiomeService).Init()
require(Services.UpgradeService).Init()
require(Services.PlayerService).Init()
