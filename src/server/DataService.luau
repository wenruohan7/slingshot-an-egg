--!strict
-- Loads and saves each player's progress with DataStoreService, and gives
-- them their offline earnings when they come back.
-- In Studio, saving needs Game Settings > Security > "Enable Studio Access to API Services".
-- Without it the game still runs, it just doesn't keep progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Pets = require(Shared.Pets)

export type Data = {
	Coins: number,
	Pets: { Pets.Pet },
	Discovered: { [string]: boolean }, -- every pet id ever hatched, for the Index
	SlingshotLevel: number,
	EggLevel: number,
	LuckLevel: number,
	Pedestals: number,
	Rebirths: number,
	LastOnline: number,
}

local DataService = {}

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 60

local store: DataStore? = nil
local loaded: { [Player]: Data } = {}
local canSave: { [Player]: boolean } = {}

-- Fired when a player's data is ready to use.
local readyEvent = Instance.new("BindableEvent")
DataService.Ready = readyEvent.Event

local function defaults(): Data
	return {
		Coins = 0,
		Pets = {},
		Discovered = {},
		SlingshotLevel = 0,
		EggLevel = 0,
		LuckLevel = 0,
		Pedestals = Config.Plot.StartPedestals,
		Rebirths = 0,
		LastOnline = os.time(),
	}
end

-- Fills in any fields missing from older saves.
local function reconcile(saved: any): Data
	local data = defaults()
	if type(saved) == "table" then
		for key, value in saved do
			if (data :: any)[key] ~= nil and type(value) == type((data :: any)[key]) then
				(data :: any)[key] = value
			end
		end
	end
	return data
end

local function withRetries<T>(attempts: number, fn: () -> T): (boolean, T?)
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`DataStore call failed (try {attempt}): {result}`)
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	return false, nil
end

function DataService.rebirthMultiplier(data: Data): number
	return Economy.rebirthMultiplier(data.Rebirths)
end

-- The pets that sit on the player's pedestals: their best ones, best first.
function DataService.bestPets(data: Data): { Pets.Pet }
	local sorted = table.clone(data.Pets)
	table.sort(sorted, function(a, b)
		return Pets.earnRate(a) > Pets.earnRate(b)
	end)
	local best = {}
	for i = 1, math.min(data.Pedestals, #sorted) do
		best[i] = sorted[i]
	end
	return best
end

-- Coins per second from the pets on the player's pedestals.
function DataService.income(data: Data): number
	local total = 0
	for _, pet in DataService.bestPets(data) do
		total += Pets.earnRate(pet)
	end
	return total * DataService.rebirthMultiplier(data)
end

function DataService.get(player: Player): Data?
	return loaded[player]
end

local function load(player: Player)
	local data: Data
	local key = "player_" .. player.UserId
	if store then
		-- One try in Studio, where a missing API access setting fails every time.
		local ok, saved = withRetries(if RunService:IsStudio() then 1 else 3, function()
			return (store :: DataStore):GetAsync(key)
		end)
		if not ok then
			-- Don't overwrite a save we couldn't read.
			warn(`Couldn't load data for {player.Name}; progress won't be saved this session.`)
			data = defaults()
		else
			data = reconcile(saved)
			-- Keep levels in range if the lists of slingshots or eggs got shorter.
			data.SlingshotLevel = math.clamp(data.SlingshotLevel, 0, #Config.Slingshots - 1)
			data.EggLevel = math.clamp(data.EggLevel, 0, #Config.Eggs - 1)
			-- Saves from before the Index: count every owned pet as found.
			for _, pet in data.Pets do
				data.Discovered[pet.Id] = true
			end
			canSave[player] = true
		end
	else
		data = defaults()
	end

	-- Offline earnings, capped.
	local away = math.clamp(os.time() - data.LastOnline, 0, Config.Offline.MaxHours * 3600)
	local offlineCoins = math.floor(DataService.income(data) * away * Config.Offline.Rate)
	data.Coins += offlineCoins
	data.LastOnline = os.time()

	if player.Parent ~= Players then
		canSave[player] = nil
		return
	end
	loaded[player] = data
	player:SetAttribute("OfflineCoins", offlineCoins)
	readyEvent:Fire(player, data)
end

local function save(player: Player)
	local data = loaded[player]
	if not (store and data and canSave[player]) then
		return
	end
	data.LastOnline = os.time()
	local key = "player_" .. player.UserId
	withRetries(3, function()
		return (store :: DataStore):SetAsync(key, data, { player.UserId })
	end)
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`Saving is off: {result}`)
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
		canSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in loaded do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local threads = 0
		for player in loaded do
			threads += 1
			task.spawn(function()
				save(player)
				threads -= 1
			end)
		end
		while threads > 0 do
			task.wait()
		end
	end)
end

return DataService
