--!strict
-- Server entry point: starts the services in dependency order.

local Services = script.Parent:WaitForChild("Services")

local NetService = require(Services:WaitForChild("NetService"))
local DataService = require(Services:WaitForChild("DataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local GameService = require(Services:WaitForChild("GameService"))

NetService.start()
DataService.start()
PlotService.start()
GameService.start()
