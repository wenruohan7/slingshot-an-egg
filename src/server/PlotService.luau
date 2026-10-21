--!strict
-- Gives each player one of the 5 plots when they join and frees it when they leave.
-- The plot number is stored as the player's "PlotIndex" attribute so clients can read it.

local Players = game:GetService("Players")

local PlotService = {}

local owners: { [number]: Player } = {}

local function claim(player: Player, plotCount: number)
	for i = 1, plotCount do
		if owners[i] == nil then
			owners[i] = player
			player:SetAttribute("PlotIndex", i)
			return
		end
	end
	warn(`No free plot for {player.Name}; is MaxPlayers above the plot count?`)
end

function PlotService.getPlotIndex(player: Player): number?
	return player:GetAttribute("PlotIndex") :: number?
end

function PlotService.init(plotCount: number)
	Players.PlayerAdded:Connect(function(player)
		claim(player, plotCount)
	end)
	for _, player in Players:GetPlayers() do
		claim(player, plotCount)
	end
	Players.PlayerRemoving:Connect(function(player)
		for i, owner in owners do
			if owner == player then
				owners[i] = nil
			end
		end
	end)
end

return PlotService
