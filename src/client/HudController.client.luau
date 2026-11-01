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

local Config = require(Shared.Config)
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

-- Big outlined counters on the left, just under the Index and Shop buttons:
-- your egg's Luck (with a four-leaf clover) and your coins (with a coin), and
-- your income under them. The same spot on PC and phones.
local counter = Instance.new("Frame")
counter.Name = "Counters"
counter.BackgroundTransparency = 1
counter.Position = UDim2.new(0, 16, 0.5, 8)
counter.Size = UDim2.fromOffset(320, 150)
counter.Parent = gui
if UserInputService.TouchEnabled then
	local small = Instance.new("UIScale")
	small.Scale = 0.75
	small.Parent = counter
end
-- Pops on coin gains; a separate frame so it doesn't fight the phone scale.
local coinRow = Instance.new("Frame")
coinRow.Name = "Coins"
coinRow.BackgroundTransparency = 1
coinRow.Position = UDim2.fromOffset(0, 54)
coinRow.Size = UDim2.new(1, 0, 0, 64)
coinRow.Parent = counter
local counterScale = Instance.new("UIScale")
counterScale.Parent = coinRow

-- A thick dark outline makes the numbers readable on any background.
local function outline(target: GuiObject, thickness: number)
	if target:IsA("TextLabel") then
		target.TextStrokeTransparency = 1
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 20, 10)
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = target
end

-- Coin: a gold disc with a darker rim and an inner ring.
local coinIcon = Instance.new("Frame")
coinIcon.AnchorPoint = Vector2.new(0, 0.5)
coinIcon.Position = UDim2.new(0, 4, 0.5, 0)
coinIcon.Size = UDim2.fromOffset(54, 54)
coinIcon.BackgroundColor3 = COIN_COLOR
coinIcon.Parent = coinRow
corner(coinIcon, UDim.new(1, 0))
local coinStroke = Instance.new("UIStroke")
coinStroke.Color = Color3.fromRGB(150, 95, 10)
coinStroke.Thickness = 4
coinStroke.Parent = coinIcon
local coinShine = Instance.new("UIGradient")
coinShine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 200, 170))
coinShine.Rotation = 60
coinShine.Parent = coinIcon
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

local coinsLabel = label({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 70, 0.5, 0),
	Size = UDim2.new(1, -74, 0, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COIN_COLOR,
	Text = "0",
	Parent = coinRow,
})
outline(coinsLabel, 4.5)
local incomeLabel = label({
	Position = UDim2.fromOffset(72, 118),
	Size = UDim2.new(1, -76, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "+0/s",
	Parent = counter,
})
outline(incomeLabel, 2.5)

-- Luck: a four-leaf clover (four green circles round a centre) and "x10".
local LUCK_COLOR = Color3.fromRGB(120, 235, 100)
local clover = Instance.new("Frame")
clover.Name = "Clover"
clover.Position = UDim2.fromOffset(6, 2)
clover.Size = UDim2.fromOffset(48, 48)
clover.BackgroundTransparency = 1
clover.Rotation = 45
clover.Parent = counter
for _, offset in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
	local leaf = Instance.new("Frame")
	leaf.Position = UDim2.fromScale(offset.X * 0.48 + 0.02, offset.Y * 0.48 + 0.02)
	leaf.Size = UDim2.fromScale(0.48, 0.48)
	leaf.BackgroundColor3 = Color3.fromRGB(70, 200, 70)
	leaf.Parent = clover
	corner(leaf, UDim.new(1, 0))
	local leafStroke = Instance.new("UIStroke")
	leafStroke.Color = Color3.fromRGB(20, 80, 25)
	leafStroke.Thickness = 2.5
	leafStroke.Parent = leaf
end
local luckLabel = label({
	Position = UDim2.fromOffset(70, 0),
	Size = UDim2.new(1, -74, 0, 52),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = LUCK_COLOR,
	Text = "x1",
	Parent = counter,
})
outline(luckLabel, 4)

local function updateLuck()
	local luck = Economy.eggLuck(attribute("EggLevel"))
	if player:GetAttribute("Pass_Luck2x") == true then
		luck *= Config.RobuxShop.LuckPassMultiplier
	end
	luckLabel.Text = `x{Format.number(luck)} Luck`
end
updateLuck()
player:GetAttributeChangedSignal("EggLevel"):Connect(updateLuck)
player:GetAttributeChangedSignal("Pass_Luck2x"):Connect(updateLuck)

-- "+12" floats away from the counter whenever coins go up.
local POP_FROM = UDim2.new(0, 230, 0.5, 0)
local POP_TO = UDim2.new(0, 230, 0.5, -40)
local function coinPop(amount: number)
	local pop = label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = POP_FROM,
		Size = UDim2.fromOffset(120, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COIN_COLOR,
		Text = "+" .. Format.coins(amount),
		Parent = coinRow,
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
-- Prompts: only your own pedestal prompt shows. Shop circles pulse.
--------------------------------------------------------------------------------

local ZONE_PULSE = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function watchPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance:GetAttribute("Kind") == "Pedestal" then
		instance.Enabled = instance:GetAttribute("OwnerUserId") == player.UserId
	elseif instance:IsA("BasePart") and instance.Name == "Zone" and instance:GetAttribute("Kind") ~= nil then
		-- Shop circles glow brighter and dimmer, forever.
		TweenService:Create(instance, ZONE_PULSE, { Transparency = 0.6 }):Play()
	end
end

local map = workspace:WaitForChild("Map")
map.DescendantAdded:Connect(watchPrompt)
for _, instance in map:GetDescendants() do
	watchPrompt(instance)
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
