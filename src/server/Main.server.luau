--!strict
-- Server entry point: builds the map, then starts each service.
-- DataService starts last so every service is already listening for its Ready event.

local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local LaunchService = require(script.Parent.LaunchService)
local SlingshotService = require(script.Parent.SlingshotService)

MapBuilder.build()
PlotService.init(MapBuilder.PLOT_COUNT)
EconomyService.init()
SlingshotService.init()
LaunchService.init()
DataService.init()
