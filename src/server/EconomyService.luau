--!strict
-- Coins: pays each player's pet income every second, and handles everything coins
-- buy: the Slingshot, Egg and Luck stands in the hub, pedestals on your own plot,
-- and rebirth. Also copies each player's data into attributes and leaderstats so
-- clients can show it.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local EconomyService = {}

local INCOME_SECONDS = 1
local MAX_STAT = 2 ^ 53 -- leaderstats are whole numbers; keep them in range

function EconomyService.notify(player: Player, text: string, kind: string?)
	Remotes.Notice:FireClient(player, text, kind or "info")
end

local function setStat(player: Player, name: string, value: number)
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		stat.Value = math.min(math.floor(value), MAX_STAT)
	end
end

-- Copies the player's data to attributes (for the client UI) and leaderstats.
function EconomyService.publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Income", DataService.income(data))
	player:SetAttribute("SlingshotLevel", data.SlingshotLevel)
	player:SetAttribute("EggLevel", data.EggLevel)
	player:SetAttribute("LuckLevel", data.LuckLevel)
	player:SetAttribute("Pedestals", data.Pedestals)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("PetCount", #data.Pets)
	player:SetAttribute("DataLoaded", true)
	setStat(player, "Coins", data.Coins)
	setStat(player, "Rebirths", data.Rebirths)
end

local function addLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

-- Takes `cost` coins if the player has them; otherwise tells them how many more they need.
local function spend(player: Player, data: DataService.Data, cost: number): boolean
	if data.Coins < cost then
		EconomyService.notify(player, `You need {Format.coins(cost - data.Coins)} more coins`, "error")
		return false
	end
	data.Coins -= cost
	return true
end

local function buyUpgrade(player: Player, kind: string)
	local data = DataService.get(player)
	local field = Economy.UPGRADE_FIELDS[kind]
	if not (data and field) then
		return
	end
	local level = (data :: any)[field] :: number
	local cost = Economy.upgradeCost(kind, level)
	if not cost then
		EconomyService.notify(player, `{kind} is at max level!`, "info")
		return
	end
	if not spend(player, data, cost) then
		return
	end
	(data :: any)[field] = level + 1
	EconomyService.publish(player)
	EconomyService.notify(player, `{kind} level {level + 1}!`, "good")
end

local function buyPedestal(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.pedestalCost(data.Pedestals)
	if not cost then
		EconomyService.notify(player, "Your plot is full of pedestals!", "info")
		return
	end
	if not spend(player, data, cost) then
		return
	end
	data.Pedestals += 1
	EconomyService.publish(player)
	PlotService.refresh(player)
	PlotService.popPedestal(player, data.Pedestals)
	EconomyService.notify(player, `New pedestal! {data.Pedestals} of {Config.Plot.MaxPedestals}`, "good")
end

local function rebirth(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not spend(player, data, Economy.rebirthCost(data.Rebirths)) then
		return
	end
	data.Coins = 0
	data.SlingshotLevel = 0
	data.EggLevel = 0
	data.LuckLevel = 0
	if not Config.Rebirth.KeepPedestals then
		data.Pedestals = Config.Plot.StartPedestals
	end
	data.Rebirths += 1
	EconomyService.publish(player)
	PlotService.refresh(player)
	PlotService.celebrate(player)
	local multiplier = Economy.rebirthMultiplier(data.Rebirths)
	EconomyService.notify(player, `Rebirth {data.Rebirths}! Coins x{Format.number(multiplier)}`, "rebirth")
end

local function hookStands()
	local map = workspace:WaitForChild("Map")
	local hub = map:WaitForChild("Hub")
	for _, stand in hub:GetChildren() do
		local counter = stand:FindFirstChild("Counter")
		local prompt = counter and counter:FindFirstChild("Prompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local kind = prompt:GetAttribute("Kind")
			prompt.Triggered:Connect(function(player)
				if kind == "Rebirth" then
					rebirth(player)
				elseif typeof(kind) == "string" then
					buyUpgrade(player, kind)
				end
			end)
		end
	end
end

local function onReady(player: Player)
	EconomyService.publish(player)
	PlotService.refresh(player)
end

function EconomyService.init()
	Players.PlayerAdded:Connect(addLeaderstats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			addLeaderstats(player)
		end
		if DataService.get(player) then
			onReady(player)
		end
	end
	DataService.Ready:Connect(onReady)
	PlotService.BuyPedestalRequested:Connect(buyPedestal)
	hookStands()

	task.spawn(function()
		while true do
			task.wait(INCOME_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.Coins += DataService.income(data) * INCOME_SECONDS
					EconomyService.publish(player)
				end
			end
		end
	end)
end

return EconomyService
