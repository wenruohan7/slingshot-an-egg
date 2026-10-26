--!strict
-- Everything on screen that isn't launching or hatching: the coin counter, short
-- notices from the server, the "welcome back" offline coins card and the rebirth
-- star burst. Also fills in the stand prompts with your own prices, hides other
-- players' pedestal prompts, and gives the pets on every plot their idle bounce.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local PET_TAG = "PlotPet" -- set by the server's PlotService
local COIN_COLOR = Color3.fromRGB(255, 215, 60)

local NOTICE_COLORS: { [string]: Color3 } = {
	good = Color3.fromRGB(120, 230, 120),
	error = Color3.fromRGB(255, 110, 110),
	info = Color3.new(1, 1, 1),
	rebirth = Color3.fromRGB(190, 150, 255),
}

local gui = Instance.new("ScreenGui")
gui.Name = "HudGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.1
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function attribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

--------------------------------------------------------------------------------
-- Coin counter
--------------------------------------------------------------------------------

-- Big coins number with a coin icon: bottom left on PC like most simulators,
-- top left on phones where the bottom left belongs to the thumbstick.
local counter = Instance.new("Frame")
counter.Name = "Coins"
counter.BackgroundTransparency = 1
counter.Size = UDim2.fromOffset(320, 84)
if UserInputService.TouchEnabled then
	counter.Position = UDim2.fromOffset(12, 8)
else
	counter.AnchorPoint = Vector2.new(0, 1)
	counter.Position = UDim2.new(0, 16, 1, -16)
end
counter.Parent = gui
local counterScale = Instance.new("UIScale")
counterScale.Parent = counter

local coinIcon = Instance.new("Frame")
coinIcon.AnchorPoint = Vector2.new(0, 1)
coinIcon.Position = UDim2.new(0, 4, 1, -6)
coinIcon.Size = UDim2.fromOffset(52, 52)
coinIcon.BackgroundColor3 = COIN_COLOR
coinIcon.Parent = counter
corner(coinIcon, UDim.new(1, 0))
local coinStroke = Instance.new("UIStroke")
coinStroke.Color = Color3.fromRGB(150, 95, 10)
coinStroke.Thickness = 4
coinStroke.Parent = coinIcon
local coinInner = Instance.new("Frame")
coinInner.AnchorPoint = Vector2.new(0.5, 0.5)
coinInner.Position = UDim2.fromScale(0.5, 0.5)
coinInner.Size = UDim2.fromScale(0.55, 0.55)
coinInner.BackgroundTransparency = 1
coinInner.Parent = coinIcon
corner(coinInner, UDim.new(1, 0))
local innerStroke = Instance.new("UIStroke")
innerStroke.Color = Color3.fromRGB(215, 160, 30)
innerStroke.Thickness = 3
innerStroke.Parent = coinInner

-- A thick dark outline makes the numbers readable on any background.
local function outline(target: TextLabel, thickness: number)
	target.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 20, 10)
	stroke.Thickness = thickness
	stroke.Parent = target
end

local coinsLabel = label({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 66, 1, 0),
	Size = UDim2.new(1, -70, 0, 58),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COIN_COLOR,
	Text = "0",
	Parent = counter,
})
outline(coinsLabel, 4)
local incomeLabel = label({
	Position = UDim2.fromOffset(68, 0),
	Size = UDim2.new(1, -70, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "+0/s",
	Parent = counter,
})
outline(incomeLabel, 2.5)

-- "+12" floats away from the counter whenever coins go up.
local POP_FROM = UDim2.new(0, 230, 1, -30)
local POP_TO = UDim2.new(0, 230, 1, -70)
local function coinPop(amount: number)
	local pop = label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = POP_FROM,
		Size = UDim2.fromOffset(120, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COIN_COLOR,
		Text = "+" .. Format.coins(amount),
		Parent = counter,
	})
	TweenService:Create(pop, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = POP_TO,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.85, function()
		pop:Destroy()
	end)
end

local shownCoins = attribute("Coins")
local function updateCoins()
	local coins = attribute("Coins")
	local gained = math.floor(coins) - math.floor(shownCoins)
	shownCoins = coins
	coinsLabel.Text = Format.coins(coins)
	if gained > 0 then
		coinPop(gained)
		counterScale.Scale = 1.08
		TweenService:Create(counterScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end
updateCoins()
player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)

local function updateIncome()
	incomeLabel.Text = `+{Format.number(attribute("Income"))}/s`
end
updateIncome()
player:GetAttributeChangedSignal("Income"):Connect(updateIncome)

--------------------------------------------------------------------------------
-- Notices
--------------------------------------------------------------------------------

local notice = label({
	Name = "Notice",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(560, 46),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})
local noticeScale = Instance.new("UIScale")
noticeScale.Parent = notice

local function showNotice(text: string, kind: string)
	notice.Text = text
	notice.TextColor3 = NOTICE_COLORS[kind] or NOTICE_COLORS.info
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.1
	noticeScale.Scale = 0.6
	TweenService:Create(noticeScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(2.2, function()
		if notice.Text == text then
			TweenService:Create(notice, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Rebirth: a big star spins across the screen.
local function starBurst()
	local star = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.1, 0.5),
		Size = UDim2.fromOffset(220, 220),
		Text = "★",
		TextColor3 = Color3.fromRGB(255, 225, 90),
		Parent = gui,
	})
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(star, info, { Position = UDim2.fromScale(1.1, 0.5), Rotation = 540 }):Play()
	task.delay(1.5, function()
		star:Destroy()
	end)
end

Remotes.Notice.OnClientEvent:Connect(function(text: string, kind: string)
	showNotice(text, kind)
	if kind == "rebirth" then
		starBurst()
	end
end)

--------------------------------------------------------------------------------
-- Welcome back card (coins earned while offline)
--------------------------------------------------------------------------------

local function showOfflineCard(coins: number)
	local card = Instance.new("Frame")
	card.Name = "WelcomeBack"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(380, 200)
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	corner(card, UDim.new(0, 24))
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = card

	label({ Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 40), Text = "Welcome back!", Parent = card })
	label({
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 50),
		Text = `Your pets earned {Format.coins(coins)} coins while you were away`,
		TextColor3 = COIN_COLOR,
		Parent = card,
	})
	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -16)
	ok.Size = UDim2.fromOffset(160, 54)
	ok.BackgroundColor3 = Color3.fromRGB(110, 210, 110)
	ok.Font = FONT
	ok.TextScaled = true
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.Text = "Yay!"
	ok.Parent = card
	corner(ok, UDim.new(1, 0))

	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	ok.Activated:Connect(function()
		local close = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0 })
		close:Play()
		close.Completed:Wait()
		card:Destroy()
	end)
end

local welcomed = false
local function onDataLoaded()
	if welcomed or player:GetAttribute("DataLoaded") ~= true then
		return
	end
	welcomed = true
	local offline = attribute("OfflineCoins")
	if offline >= 1 then
		showOfflineCard(offline)
	end
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(onDataLoaded)
onDataLoaded()

--------------------------------------------------------------------------------
-- Prompts: your prices on the stands, and only your own pedestal prompt
--------------------------------------------------------------------------------

local standPrompts: { [ProximityPrompt]: string } = {}

local function priceText(cost: number?): string
	return if cost then `{Format.coins(cost)} coins` else "Max level"
end

local function updateStandPrompt(prompt: ProximityPrompt, kind: string)
	if kind == "Slingshot" then
		local level = attribute("SlingshotLevel")
		local now = math.floor(Economy.launchPower(level))
		local nextPower = math.floor(Economy.launchPower(level + 1))
		prompt.ObjectText = `Slingshot Lv {level}: power {now} → {nextPower}`
		prompt.ActionText = "Upgrade: " .. priceText(Economy.upgradeCost(kind, level))
	elseif kind == "Egg" then
		local level = attribute("EggLevel")
		local boost = math.floor((Economy.eggBoost(level) - 1) * 100 + 0.5)
		prompt.ObjectText = `Eggs Lv {level}: Rare and up +{boost}%`
		prompt.ActionText = "Upgrade: " .. priceText(Economy.upgradeCost(kind, level))
	elseif kind == "Luck" then
		local level = attribute("LuckLevel")
		local boost = math.floor((Economy.luckBoost(level) - 1) * 100 + 0.5)
		prompt.ObjectText = `Luck Lv {level}: mutations +{boost}%`
		prompt.ActionText = "Upgrade: " .. priceText(Economy.upgradeCost(kind, level))
	elseif kind == "Rebirth" then
		local rebirths = attribute("Rebirths")
		local nextMultiplier = Economy.rebirthMultiplier(rebirths + 1)
		prompt.ObjectText = `Rebirth: coins x{Format.number(nextMultiplier)}, keep your pets`
		prompt.ActionText = "Rebirth: " .. priceText(Economy.rebirthCost(rebirths))
	end
end

local function updateAllStands()
	for prompt, kind in standPrompts do
		if prompt.Parent then
			updateStandPrompt(prompt, kind)
		else
			standPrompts[prompt] = nil
		end
	end
end

local function watchPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local kind = instance:GetAttribute("Kind")
	if kind == "Pedestal" then
		instance.Enabled = instance:GetAttribute("OwnerUserId") == player.UserId
	elseif typeof(kind) == "string" then
		standPrompts[instance] = kind
		updateStandPrompt(instance, kind)
	end
end

local map = workspace:WaitForChild("Map")
map.DescendantAdded:Connect(watchPrompt)
for _, instance in map:GetDescendants() do
	watchPrompt(instance)
end
for _, name in { "SlingshotLevel", "EggLevel", "LuckLevel", "Rebirths" } do
	player:GetAttributeChangedSignal(name):Connect(updateAllStands)
end

--------------------------------------------------------------------------------
-- Pet idle bounce
--------------------------------------------------------------------------------

type Bouncer = { base: CFrame, phase: number }
local bouncers: { [Model]: Bouncer } = {}

local function addBouncer(instance: Instance)
	if instance:IsA("Model") then
		bouncers[instance] = { base = instance:GetPivot(), phase = math.random() * 10 }
	end
end
CollectionService:GetInstanceAddedSignal(PET_TAG):Connect(addBouncer)
CollectionService:GetInstanceRemovedSignal(PET_TAG):Connect(function(instance)
	bouncers[instance :: Model] = nil
end)
for _, instance in CollectionService:GetTagged(PET_TAG) do
	addBouncer(instance)
end

local BOUNCE_RANGE = 150 -- only animate pets this close to the camera
RunService.RenderStepped:Connect(function()
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	local now = os.clock()
	for model, bouncer in bouncers do
		if (bouncer.base.Position - cameraPosition).Magnitude < BOUNCE_RANGE then
			local t = now + bouncer.phase
			local hop = math.abs(math.sin(t * 2.6)) * 0.5
			local sway = math.sin(t * 1.3) * 0.25
			model:PivotTo(bouncer.base * CFrame.new(0, hop, 0) * CFrame.Angles(0, sway, 0))
		end
	end
end)
