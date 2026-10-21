--!strict
-- Server entry point: builds the map, then starts each service.

local MapBuilder = require(script.Parent.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local LaunchService = require(script.Parent.LaunchService)

MapBuilder.build()
PlotService.init(MapBuilder.PLOT_COUNT)
LaunchService.init()
