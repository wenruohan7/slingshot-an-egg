--!strict
-- Gives each player one of the 5 plots when they join and frees it when they leave.
-- The plot number is stored as the player's "PlotIndex" attribute so clients can read it.
-- Also keeps each plot showing its owner's progress: their best pets on the unlocked
-- pedestals, the locked ones see-through, a buy prompt on the next locked one, and a
-- sign with the owner's name and coins per second.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local PetModel = require(Shared.PetModel)
local Pets = require(Shared.Pets)
local DataService = require(script.Parent.DataService)

local PlotService = {}

-- Clients find plot pets by this tag to play their idle bounce.
PlotService.PET_TAG = "PlotPet"

local OPEN_COLOR = Color3.fromRGB(240, 240, 250)
local LOCKED_COLOR = Color3.fromRGB(150, 150, 165)
local LOCKED_TRANSPARENCY = 0.7

local owners: { [number]: Player } = {}
local plotCount = 0

-- Fired with (player) when a player asks to buy their next pedestal.
local buyPedestalEvent = Instance.new("BindableEvent")
PlotService.BuyPedestalRequested = buyPedestalEvent.Event

local function plotPart(index: number): BasePart?
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local plot = hub and hub:FindFirstChild("Plot" .. index)
	if plot and plot:IsA("BasePart") then
		return plot
	end
	return nil
end

local function pedestalPart(plot: BasePart, n: number): BasePart?
	local pedestal = plot:FindFirstChild("Pedestal" .. n)
	if pedestal and pedestal:IsA("BasePart") then
		return pedestal
	end
	return nil
end

local function setSign(plot: BasePart, text: string)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- A small name tag over a plot pet: its name in its colour and what it earns.
local function addTag(model: Model, pet: Pets.Pet)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, body.Size.Y / 2 + 1.6, 0)
	gui.MaxDistance = 70
	gui.Parent = body

	local lines = {
		{ Text = Pets.displayName(pet), Color = Pets.color(pet), Y = 0 },
		{ Text = `+{Format.number(Pets.earnRate(pet))}/s`, Color = Color3.fromRGB(255, 225, 90), Y = 0.55 },
	}
	for _, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, line.Y)
		label.Size = UDim2.fromScale(1, 0.45)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = line.Text
		label.TextColor3 = line.Color
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
	end
end

-- A key for which pets are shown, so an unchanged plot isn't rebuilt.
local function petsKey(pets: { Pets.Pet }): string
	local parts = {}
	for i, pet in pets do
		parts[i] = `{pet.Id}:{pet.Mutation or 0}:{if pet.Big then 1 else 0}`
	end
	return table.concat(parts, ",")
end

local function drawPets(plot: BasePart, pets: { Pets.Pet })
	local key = petsKey(pets)
	local folder = plot:FindFirstChild("Pets")
	if folder and folder:GetAttribute("Key") == key then
		return
	end
	if folder then
		folder:Destroy()
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Pets"
	newFolder:SetAttribute("Key", key)
	for i, pet in pets do
		local pedestal = pedestalPart(plot, i)
		if pedestal then
			local top = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2, 0)
			local model = PetModel.build(pet, CFrame.new(top))
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			addTag(model, pet)
			CollectionService:AddTag(model, PlotService.PET_TAG)
			model.Parent = newFolder
		end
	end
	newFolder.Parent = plot
end

-- Shows a plot's pedestals as open or locked, with a buy prompt on the next one.
local function drawPedestals(plot: BasePart, unlocked: number, owner: Player?)
	for n = 1, Config.Plot.MaxPedestals do
		local pedestal = pedestalPart(plot, n)
		if pedestal then
			local open = n <= unlocked
			pedestal.Color = if open then OPEN_COLOR else LOCKED_COLOR
			pedestal.Transparency = if open then 0 else LOCKED_TRANSPARENCY
			local old = pedestal:FindFirstChild("BuyPrompt")
			if old then
				old:Destroy()
			end
		end
	end

	local cost = Economy.pedestalCost(unlocked)
	local nextPedestal = pedestalPart(plot, unlocked + 1)
	if not (owner and cost and nextPedestal) then
		return
	end
	-- Only the owner sees this prompt; the client hides it from everyone else.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ObjectText = "Pedestal"
	prompt.ActionText = `Buy: {Format.coins(cost)} coins`
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "Pedestal")
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Triggered:Connect(function(who)
		if who == owner then
			buyPedestalEvent:Fire(owner)
		end
	end)
	prompt.Parent = nextPedestal
end

local function drawEmpty(index: number)
	local plot = plotPart(index)
	if not plot then
		return
	end
	drawPets(plot, {})
	drawPedestals(plot, Config.Plot.StartPedestals, nil)
	setSign(plot, `Plot {index}`)
end

function PlotService.getPlotIndex(player: Player): number?
	return player:GetAttribute("PlotIndex") :: number?
end

-- The player's plot part, if they have one.
function PlotService.getPlot(player: Player): BasePart?
	local index = PlotService.getPlotIndex(player)
	return if index then plotPart(index) else nil
end

-- Redraws the player's plot from their data. Call after anything that changes
-- their pets, pedestals or income.
function PlotService.refresh(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	if not (plot and data) then
		return
	end
	drawPets(plot, DataService.bestPets(data))
	drawPedestals(plot, data.Pedestals, player)
	setSign(plot, `{player.DisplayName}'s plot\n+{Format.number(DataService.income(data))}/s`)
end

-- A newly bought pedestal rises out of the plot with a little overshoot.
function PlotService.popPedestal(player: Player, n: number)
	local plot = PlotService.getPlot(player)
	local pedestal = plot and pedestalPart(plot, n)
	if not pedestal then
		return
	end
	local final = pedestal.CFrame
	pedestal.CFrame = final - Vector3.new(0, 1.6, 0)
	TweenService:Create(pedestal, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final })
		:Play()
end

-- Makes the player's plot glow for a moment (used for rebirth).
function PlotService.celebrate(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(255, 220, 90)
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.FillTransparency = 0.3
	glow.Adornee = plot
	glow.Parent = plot
	TweenService:Create(glow, TweenInfo.new(2.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(2.6, function()
		glow:Destroy()
	end)
end

local function claim(player: Player)
	for i = 1, plotCount do
		if not owners[i] then
			owners[i] = player
			player:SetAttribute("PlotIndex", i)
			PlotService.refresh(player)
			return
		end
	end
	warn(`No free plot for {player.Name}; is MaxPlayers above the plot count?`)
end

function PlotService.init(count: number)
	plotCount = count
	for i = 1, plotCount do
		drawEmpty(i)
	end
	Players.PlayerAdded:Connect(claim)
	for _, player in Players:GetPlayers() do
		claim(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		for i = 1, plotCount do
			if owners[i] == player then
				owners[i] = nil
				drawEmpty(i)
			end
		end
	end)
end

return PlotService
