--!strict
-- Launch controls: step onto the shooting spot and the draw starts by itself;
-- tap anywhere (or click, or E) to shoot, or jump to step away. Holding the big
-- launch button (or the E key) and letting go works too. Also draws the
-- bouncing charge meter, the slingshot band pulling back and snapping,
-- the stage word that pops up on release (with a ring burst for the best ones),
-- a camera that follows the egg, and a banner naming the zone it lands in.
-- While drawing, the player is turned down the lane and held in place (anchored)
-- until the release is over. The shot camera and impact frames are in
-- ShotCamera, the body animation in PoseController; the hatch is in HatchController.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Charge = require(Shared.Charge)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Lane = require(Shared.Lane)
local Remotes = require(Shared.Remotes)
local SlingshotModel = require(Shared.SlingshotModel)

local LocalCharge = require(script.Parent:WaitForChild("LocalCharge"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- No inventory bar: the bow comes out by itself on the shooting spot
-- (SlingshotService), and there is nothing else to hold.
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 20 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)

local FONT = Enum.Font.FredokaOne
local LAUNCH_KEY = Enum.KeyCode.E

local charging = false
local chargeStart = 0
local flying = false
local chargeInput: InputObject? = nil -- the touch, click or key that started the charge
local chargedByTool = false -- started by Tool.Activated instead
local lockedHumanoid: Humanoid? = nil -- turned to face the lane while charging
local anchoredRoot: BasePart? = nil -- held in place from the draw until the release is over
local RELEASE_HOLD = 0.5 -- seconds the player stays put after letting go

-- Drives the band snap-back after release; tweening it springs the pouch forward.
local pull = Instance.new("NumberValue")
local snapTween: Tween? = nil

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "LaunchGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

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

local button = Instance.new("TextButton")
button.Name = "LaunchButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -40, 1, -40)
button.Size = UDim2.fromOffset(150, 150)
button.BackgroundColor3 = Color3.fromRGB(255, 120, 160)
button.Font = FONT
button.TextScaled = true
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "🥚\nHOLD"
button.AutoButtonColor = false
button.Visible = false
button.Parent = gui
corner(button, UDim.new(1, 0))
local buttonScale = Instance.new("UIScale")
buttonScale.Parent = button

-- The meter (like Tmuk's reference): a tall rounded tube of chunky cells, red
-- at the bottom through orange and yellow to green at the top, with a white
-- needle sliding up and down it. The top cells are the Perfect band.
local METER_CELLS = 12
local CELL_GAP = 3
local CELL_COLORS = {
	Color3.fromRGB(235, 55, 50), -- bottom
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(110, 225, 70), -- top
}

local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.AnchorPoint = Vector2.new(1, 0.5)
meter.Position = UDim2.new(1, -230, 0.42, 0)
meter.Size = UDim2.fromOffset(50, 330)
meter.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
meter.Visible = false
meter.Parent = gui
corner(meter, UDim.new(1, 0))
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(20, 18, 28)
frameStroke.Thickness = 4
frameStroke.Parent = meter

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.fromScale(0.5, 0.5)
bar.Size = UDim2.new(1, -12, 1, -14)
bar.BackgroundTransparency = 1
bar.Parent = meter

-- On phones, keep the button and meter clear of the jump button, which sits
-- within about 230 px of the bottom-right corner in every layout.
if UserInputService.TouchEnabled then
	button.Position = UDim2.new(1, -240, 1, -30)
	meter.AnchorPoint = Vector2.new(1, 1)
	meter.Position = UDim2.new(1, -410, 1, -30)
end

local stages = Config.Charge.Stages

local function cellColor(t: number): Color3
	local scaled = t * (#CELL_COLORS - 1)
	local i = math.clamp(math.floor(scaled) + 1, 1, #CELL_COLORS - 1)
	return CELL_COLORS[i]:Lerp(CELL_COLORS[i + 1], scaled - (i - 1))
end

for i = 1, METER_CELLS do
	local t = (i - 1) / (METER_CELLS - 1) -- 0 bottom, 1 top
	local cell = Instance.new("Frame")
	cell.Name = "Cell" .. i
	cell.AnchorPoint = Vector2.new(0.5, 1)
	cell.Position = UDim2.new(0.5, 0, 1 - (i - 1) / METER_CELLS, 0)
	cell.Size = UDim2.new(1, 0, 1 / METER_CELLS, -CELL_GAP)
	cell.BorderSizePixel = 0
	cell.BackgroundColor3 = cellColor(t)
	cell.Parent = bar
	corner(cell, UDim.new(0, if i == 1 or i == METER_CELLS then 12 else 4))
	-- A lighter top edge on each cell, so they look like little blocks.
	local light = Instance.new("UIGradient")
	light.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	light.Rotation = 90
	light.Parent = cell
end

-- A light shine down the left side, like a glass tube.
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.Position = UDim2.new(0, 4, 0, 8)
shine.Size = UDim2.new(0, 6, 1, -16)
shine.BorderSizePixel = 0
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BackgroundTransparency = 0.6
shine.ZIndex = 2
shine.Parent = bar
corner(shine, UDim.new(1, 0))

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Size = UDim2.new(1, 26, 0, 12)
needle.BackgroundColor3 = Color3.new(1, 1, 1)
needle.ZIndex = 3
needle.Parent = bar
local needleStroke = Instance.new("UIStroke")
needleStroke.Color = Color3.fromRGB(20, 20, 30)
needleStroke.Thickness = 2
needleStroke.Parent = needle
corner(needle, UDim.new(1, 0))

-- "+342" beside the needle: the power you'd get if you let go now (the studs the
-- egg would fly), so it climbs as you buy better bows.
local needleTag = label({
	Name = "PowerTag",
	AnchorPoint = if UserInputService.TouchEnabled then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
	Position = UDim2.new(0, -10, 0.5, 0),
	Size = UDim2.fromOffset(110, 34),
	TextXAlignment = if UserInputService.TouchEnabled then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
	TextStrokeTransparency = 1,
	ZIndex = 3,
	Parent = meter,
})
local needleTagStroke = Instance.new("UIStroke")
needleTagStroke.Color = Color3.fromRGB(20, 20, 30)
needleTagStroke.Thickness = 3
needleTagStroke.Parent = needleTag

local meterHint = label({
	Name = "LetGoHint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.fromOffset(220, 32),
	Text = "LET GO TO SHOOT!",
	TextStrokeTransparency = 1,
	Parent = meter,
})
local meterHintStroke = Instance.new("UIStroke")
meterHintStroke.Color = Color3.fromRGB(20, 20, 30)
meterHintStroke.Thickness = 3
meterHintStroke.Parent = meterHint
-- "x100 LUCK" badge in the top right while you aim: your egg's Luck.
local luckBadge = Instance.new("Frame")
luckBadge.Name = "LuckBadge"
luckBadge.AnchorPoint = Vector2.new(1, 0)
luckBadge.Position = UDim2.new(1, -24, 0, 70)
luckBadge.Size = UDim2.fromOffset(190, 52)
luckBadge.BackgroundColor3 = Color3.new(1, 1, 1)
luckBadge.Visible = false
luckBadge.Parent = gui
corner(luckBadge, UDim.new(1, 0))
local badgeStroke = Instance.new("UIStroke")
badgeStroke.Color = Color3.fromRGB(20, 18, 28)
badgeStroke.Thickness = 3
badgeStroke.Parent = luckBadge
local badgeFill = Instance.new("UIGradient")
badgeFill.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(130, 70, 220))
badgeFill.Rotation = 90
badgeFill.Parent = luckBadge
local clover = Instance.new("Frame")
clover.Name = "Clover"
clover.AnchorPoint = Vector2.new(0.5, 0.5)
clover.Position = UDim2.new(0, 20, 0.5, 0)
clover.Size = UDim2.fromOffset(50, 50)
clover.BackgroundTransparency = 1
clover.Rotation = 45
clover.Parent = luckBadge
for _, offset in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
	local leaf = Instance.new("Frame")
	leaf.Position = UDim2.fromScale(offset.X * 0.48 + 0.02, offset.Y * 0.48 + 0.02)
	leaf.Size = UDim2.fromScale(0.48, 0.48)
	leaf.BackgroundColor3 = Color3.fromRGB(80, 210, 80)
	leaf.Parent = clover
	corner(leaf, UDim.new(1, 0))
	local leafStroke = Instance.new("UIStroke")
	leafStroke.Color = Color3.fromRGB(20, 80, 25)
	leafStroke.Thickness = 2.5
	leafStroke.Parent = leaf
end
local luckBadgeText = label({
	Position = UDim2.fromOffset(52, 8),
	Size = UDim2.new(1, -64, 1, -16),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextStrokeTransparency = 1,
	Text = "x1 LUCK",
	Parent = luckBadge,
})
local luckBadgeStroke = Instance.new("UIStroke")
luckBadgeStroke.Color = Color3.fromRGB(20, 18, 28)
luckBadgeStroke.Thickness = 2.5
luckBadgeStroke.Parent = luckBadgeText

local leaveHint = label({
	Name = "LeaveHint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 44),
	Size = UDim2.fromOffset(200, 22),
	Text = "Jump to step away",
	TextColor3 = Color3.fromRGB(225, 225, 235),
	TextStrokeTransparency = 1,
	Visible = false,
	Parent = meter,
})
local leaveHintStroke = Instance.new("UIStroke")
leaveHintStroke.Color = Color3.fromRGB(20, 20, 30)
leaveHintStroke.Thickness = 2
leaveHintStroke.Parent = leaveHint

-- "+342 POWER" floats up from the meter when you let go.
local function powerPop(amount: number, color: Color3)
	local pop = label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -230, 0.5, -40),
		Size = UDim2.fromOffset(260, 44),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		TextStrokeTransparency = 1,
		Text = `+{Format.number(amount)} POWER`,
		ZIndex = 4,
		Parent = gui,
	})
	if UserInputService.TouchEnabled then
		pop.AnchorPoint = Vector2.new(1, 1)
		pop.Position = UDim2.new(1, -420, 1, -300)
	end
	local popStroke = Instance.new("UIStroke")
	popStroke.Color = Color3.fromRGB(20, 20, 30)
	popStroke.Thickness = 3
	popStroke.Parent = pop
	local popScale = Instance.new("UIScale")
	popScale.Scale = 0.5
	popScale.Parent = pop
	TweenService:Create(popScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local rise = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pop, rise, { Position = pop.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 }):Play()
	TweenService:Create(popStroke, rise, { Transparency = 1 }):Play()
	task.delay(1.2, function()
		pop:Destroy()
	end)
end

-- Studs the egg flies at this meter value with your current bow.
local function powerAt(value: number): number
	local level = player:GetAttribute("SlingshotLevel")
	return Economy.launchPower(if typeof(level) == "number" then level else 0) * Charge.stageFor(value).Power
end

local stagePopup = label({
	Name = "StagePopup",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.fromOffset(420, 90),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})
local popupScale = Instance.new("UIScale")
popupScale.Parent = stagePopup

-- A ring that bursts out behind the stage word on a Perfect or Amazing release.
local ring = Instance.new("Frame")
ring.Name = "RingBurst"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = stagePopup.Position
ring.BackgroundTransparency = 1
ring.Visible = false
ring.Parent = gui
corner(ring, UDim.new(1, 0))
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 10
ringStroke.Parent = ring

local function ringBurst(color: Color3)
	ring.Visible = true
	ring.Size = UDim2.fromOffset(60, 60)
	ringStroke.Color = color
	ringStroke.Transparency = 0
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(460, 460) }):Play()
	TweenService:Create(ringStroke, info, { Transparency = 1 }):Play()
end

local zoneBanner = label({
	Name = "ZoneBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 185), -- below the hint line and the distance bar
	Size = UDim2.fromOffset(520, 70),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})

-- Distance bar along the top while an egg flies: the 8 zones in their colours,
-- an egg marker that moves with your egg, and the part not reached yet dimmed.
local distanceBar = Instance.new("Frame")
distanceBar.Name = "DistanceBar"
distanceBar.AnchorPoint = Vector2.new(0.5, 0)
distanceBar.Position = UDim2.new(0.5, 0, 0, 128) -- under the hint line
distanceBar.Size = UDim2.new(0.62, 0, 0, 38)
distanceBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
distanceBar.Visible = false
distanceBar.Parent = gui
corner(distanceBar, UDim.new(0, 12))
local distanceStroke = Instance.new("UIStroke")
distanceStroke.Color = Color3.new(1, 1, 1)
distanceStroke.Thickness = 3
distanceStroke.Parent = distanceBar
local barLimit = Instance.new("UISizeConstraint")
barLimit.MaxSize = Vector2.new(820, 38)
barLimit.Parent = distanceBar

local zoneStrip = Instance.new("Frame")
zoneStrip.Name = "Zones"
zoneStrip.Position = UDim2.fromOffset(4, 4)
zoneStrip.Size = UDim2.new(1, -8, 1, -8)
zoneStrip.BackgroundTransparency = 1
zoneStrip.ClipsDescendants = true
zoneStrip.Parent = distanceBar
corner(zoneStrip, UDim.new(0, 9))
for i, zone in Config.Zones do
	local segment = Instance.new("Frame")
	segment.Name = zone.Name
	segment.Position = UDim2.fromScale((i - 1) / #Config.Zones, 0)
	segment.Size = UDim2.fromScale(1 / #Config.Zones, 1)
	segment.BackgroundColor3 = zone.Color
	segment.BorderSizePixel = 0
	segment.Parent = zoneStrip
	local name = label({
		Position = UDim2.fromScale(0.05, 0.12),
		Size = UDim2.fromScale(0.9, 0.76),
		Text = zone.Name,
		TextStrokeTransparency = 0.3,
		Parent = segment,
	})
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 18
	nameSize.Parent = name
	if i > 1 then
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 2, 1, 0)
		line.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		line.BorderSizePixel = 0
		line.Parent = segment
	end
end
local notReached = Instance.new("Frame")
notReached.Name = "NotReached"
notReached.AnchorPoint = Vector2.new(1, 0)
notReached.Position = UDim2.fromScale(1, 0)
notReached.Size = UDim2.fromScale(1, 1)
notReached.BackgroundColor3 = Color3.new(0, 0, 0)
notReached.BackgroundTransparency = 0.55
notReached.BorderSizePixel = 0
notReached.ZIndex = 2
notReached.Parent = zoneStrip

local eggMarker = label({
	Name = "EggMarker",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(44, 44),
	Text = "🥚",
	ZIndex = 3,
	Parent = distanceBar,
})

-- Above the bar while the egg flies: the distance so far (climbing), the zone
-- it's over, and your egg's Luck.
local flightReadout = Instance.new("Frame")
flightReadout.Name = "FlightReadout"
flightReadout.AnchorPoint = Vector2.new(0.5, 0)
flightReadout.Position = UDim2.new(0.5, 0, 0, 62)
flightReadout.Size = UDim2.fromOffset(420, 64)
flightReadout.BackgroundTransparency = 1
flightReadout.Visible = false
flightReadout.Parent = gui
local function readoutText(props: { [string]: any }): TextLabel
	local l = label(props)
	l.TextStrokeTransparency = 1
	l.Parent = flightReadout
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(20, 20, 30)
	st.Thickness = 3
	st.Parent = l
	return l
end
local distanceText = readoutText({
	Name = "Distance",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(0.5, -6, 0, 44),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "0 studs",
})
local luckText = readoutText({
	Name = "Luck",
	Position = UDim2.new(0.5, 6, 0, 4),
	Size = UDim2.new(0.5, -6, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(130, 235, 110),
	Text = "x1 LUCK",
})
local zoneText = readoutText({
	Name = "Zone",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 42),
	Size = UDim2.fromOffset(300, 24),
	Text = "",
})

local function eggLuck(): number
	local level = player:GetAttribute("EggLevel")
	local luck = Economy.eggLuck(if typeof(level) == "number" then level else 0)
	if player:GetAttribute("Pass_Luck2x") == true then
		luck *= Config.RobuxShop.LuckPassMultiplier
	end
	return luck
end

local trackedEgg: BasePart? = nil

local function setDistanceBar(fraction: number)
	fraction = math.clamp(fraction, 0, 1)
	notReached.Size = UDim2.fromScale(1 - fraction, 1)
	eggMarker.Position = UDim2.fromScale(fraction, 0.5)
end

local function showDistanceBar(egg: BasePart)
	trackedEgg = egg
	setDistanceBar(0)
	distanceBar.Visible = true
	luckText.Text = `x{Format.number(eggLuck())} LUCK`
	distanceText.Text = "0 studs"
	zoneText.Text = Config.Zones[1].Name
	zoneText.TextColor3 = Config.Zones[1].Color
	flightReadout.Visible = true
end

-- Hides the bar a moment after landing, unless a new egg is already flying.
local function hideDistanceBar(after: number)
	local egg = trackedEgg
	task.delay(after, function()
		if trackedEgg == egg then
			trackedEgg = nil
			distanceBar.Visible = false
			flightReadout.Visible = false
		end
	end)
end

RunService.RenderStepped:Connect(function()
	local egg = trackedEgg
	if egg and egg.Parent then
		local distance = math.max(0, egg.Position.X - Config.Lane.StartX)
		setDistanceBar(distance / Lane.Length)
		distanceText.Text = `{Format.commas(distance)} studs`
		local zone = Config.Zones[Lane.zoneAt(distance)]
		if zone and zoneText.Text ~= zone.Name then
			zoneText.Text = zone.Name
			zoneText.TextColor3 = zone.Color
			local pop: UIScale = zoneText:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			pop.Parent = zoneText
			pop.Scale = 1.5
			TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	end
end)

-- Pops a label in big, then fades it out.
local function popText(target: TextLabel, scale: UIScale?, text: string, color: Color3, hold: number)
	target.Text = text
	target.TextColor3 = color
	target.TextTransparency = 0
	target.TextStrokeTransparency = 0.1
	if scale then
		scale.Scale = 0.4
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	task.delay(hold, function()
		if target.Text == text then
			TweenService:Create(target, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

--------------------------------------------------------------------------------
-- Charging
--------------------------------------------------------------------------------

-- The slingshot, if it's in the player's hand.
local function heldSlingshot(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(SlingshotModel.NAME)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

-- The slingshot the band animation drives. It keeps driving it after it's put
-- away, so the band always finishes snapping back to rest.
local hookedTool: Tool? = nil

pull.Changed:Connect(function(value)
	if hookedTool then
		SlingshotModel.setPull(hookedTool, value)
	end
end)

local function canLaunch(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return heldSlingshot() ~= nil
		and player:GetAttribute("DataLoaded") == true
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and Lane.isOnLaunchSpot(root.Position)
end

-- Turns the character to face down the lane (where the egg flies) and holds
-- that facing until the charge ends.
local function faceLane()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.xAxis)
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = true -- feet planted: no walking or sliding mid-shot
		anchoredRoot = root
	end
	if humanoid then
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		lockedHumanoid = humanoid
	end
end

-- Lets the player move again (after the release, unless a new draw has started).
local function unlockPlayer()
	if charging then
		return
	end
	if anchoredRoot then
		anchoredRoot.Anchored = false
		anchoredRoot = nil
	end
	if lockedHumanoid then
		lockedHumanoid.AutoRotate = true
		lockedHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		lockedHumanoid = nil
	end
end

-- Whether your egg is still in the air: from the server's EggInFlight attribute,
-- this client's own view of the flight, and a short lock right after letting go
-- (before the server's answer arrives).
local RELEASE_LOCK = 1
local lastRelease = -math.huge
local function eggInAir(): boolean
	return flying or player:GetAttribute("EggInFlight") == true or os.clock() - lastRelease < RELEASE_LOCK
end

-- Auto charge: stepping onto the shooting spot starts the draw by itself, and
-- any tap (or click, or E) shoots. Jumping steps away without shooting, and
-- the draw won't start again until you've walked off the spot and back on.
local AUTO_DELAY = 0.35 -- seconds on the spot before the draw starts
local autoCharge = false -- the current draw was started by the spot
local autoBlocked = false -- jumped out of a draw: wait until off the spot
local onSpotSince: number? = nil

local function startCharge(input: InputObject?, auto: boolean?)
	if charging or eggInAir() or not canLaunch() then
		return
	end
	charging = true
	autoCharge = auto == true
	meterHint.Text = if autoCharge then "TAP TO SHOOT!" else "LET GO TO SHOOT!"
	meterHint.TextColor3 = Color3.new(1, 1, 1)
	luckBadgeText.Text = `x{Format.number(eggLuck())} LUCK`
	luckBadge.Visible = true
	leaveHint.Visible = autoCharge
	button.Text = if autoCharge then "🥚\nTAP!" else "🥚\nHOLD"
	chargeInput = input
	chargedByTool = input == nil and not autoCharge
	chargeStart = os.clock()
	LocalCharge.charging = true
	LocalCharge.startedAt = chargeStart
	if snapTween then
		snapTween:Cancel()
		snapTween = nil
	end
	faceLane()
	meter.Visible = true
	Remotes.ChargeStart:FireServer()
	TweenService:Create(buttonScale, TweenInfo.new(0.15), { Scale = 0.88 }):Play()
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	autoCharge = false
	lastRelease = os.clock()
	chargeInput = nil
	chargedByTool = false
	local releaseValue = Charge.valueAt(os.clock() - chargeStart)
	local stage = Charge.stageFor(releaseValue).Name
	powerPop(powerAt(releaseValue), Charge.stageFor(releaseValue).Color)
	-- The stage word under the meter, like "PERFECT!", while it fades out.
	meterHint.Text = string.upper(stage) .. "!"
	meterHint.TextColor3 = Charge.stageFor(releaseValue).Color
	leaveHint.Visible = false
	LocalCharge.charging = false
	LocalCharge.releaseStage = stage
	LocalCharge.releasePull = pull.Value
	LocalCharge.releasedAt = os.clock()
	local hold = RELEASE_HOLD + if stage == stages[1].Name then Config.Charge.PerfectFreeze else 0
	task.delay(hold, unlockPlayer)
	Remotes.ChargeRelease:FireServer()
	local tween = TweenService:Create(pull, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = 0 })
	snapTween = tween
	tween:Play()
	TweenService:Create(buttonScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.7, function()
		if not charging then
			meter.Visible = false
			luckBadge.Visible = false
		end
	end)
end

-- Steps out of the draw without shooting (jumping off the spot).
local function cancelCharge()
	if not charging then
		return
	end
	charging = false
	autoCharge = false
	autoBlocked = true
	chargeInput = nil
	chargedByTool = false
	LocalCharge.charging = false
	Remotes.ChargeCancel:FireServer()
	unlockPlayer()
	local tween = TweenService:Create(pull, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 })
	snapTween = tween
	tween:Play()
	TweenService:Create(buttonScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	meter.Visible = false
	luckBadge.Visible = false
end

UserInputService.JumpRequest:Connect(function()
	if charging and autoCharge then
		cancelCharge()
	end
end)

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

button.InputBegan:Connect(function(input)
	if isPress(input) then
		if charging and autoCharge then
			releaseCharge()
		else
			startCharge(input)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if charging and autoCharge then
		-- Tap anywhere to shoot.
		if isPress(input) or input.KeyCode == LAUNCH_KEY then
			releaseCharge()
		end
	elseif input.KeyCode == LAUNCH_KEY then
		startCharge(input)
	end
end)

-- Letting go anywhere on screen counts, so sliding a finger off the button still
-- launches. On touch screens only the finger that started the charge counts, so
-- moving or jumping with another finger doesn't fire the egg.
UserInputService.InputEnded:Connect(function(input: InputObject)
	if not charging or chargedByTool or autoCharge then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if input == chargeInput then
			releaseCharge()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == LAUNCH_KEY then
		releaseCharge()
	end
end)

-- Clicking and holding with the slingshot in hand works too (and tapping on mobile).
local function hookTool(tool: Tool?)
	if tool == nil or tool == hookedTool then
		return
	end
	hookedTool = tool
	tool.Activated:Connect(function()
		if charging and autoCharge then
			releaseCharge()
		else
			startCharge(nil)
		end
	end)
	tool.Deactivated:Connect(function()
		if chargedByTool then
			releaseCharge()
		end
	end)
end

RunService.RenderStepped:Connect(function()
	hookTool(heldSlingshot())
	local ready = canLaunch()
	button.Visible = (charging or not eggInAir()) and ready
	if charging and not ready then
		-- Bow gone or off the spot mid-draw: a spot-started draw just stops,
		-- a held one lets go.
		if autoCharge then
			cancelCharge()
		else
			releaseCharge()
		end
	end
	-- Auto charge on the spot.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local onSpot = root ~= nil and root:IsA("BasePart") and Lane.isOnLaunchSpot(root.Position)
	if not onSpot then
		onSpotSince = nil
		autoBlocked = false
	elseif onSpotSince == nil then
		onSpotSince = os.clock()
	end
	if
		ready
		and not charging
		and not autoBlocked
		and not eggInAir()
		and onSpotSince ~= nil
		and os.clock() - onSpotSince >= AUTO_DELAY
	then
		startCharge(nil, true)
	end
	if charging then
		local value = Charge.valueAt(os.clock() - chargeStart)
		needle.Position = UDim2.fromScale(0.5, 1 - value)
		needleTag.Position = if UserInputService.TouchEnabled
			then UDim2.new(0, -10, 1 - value, 0)
			else UDim2.new(1, 12, 1 - value, 0)
		needleTag.Text = `+{Format.number(powerAt(value))}`
		pull.Value = SlingshotModel.drawFor(value)
	end
	-- Clear the screen while aiming and while the egg flies: the menu buttons
	-- and the hint line hide, the coin counter stays.
	local menuGui = playerGui:FindFirstChild("MenuGui")
	if menuGui and menuGui:IsA("ScreenGui") then
		menuGui.Enabled = not (charging or flying)
	end
end)

--------------------------------------------------------------------------------
-- Flight and landing
--------------------------------------------------------------------------------

local function stageColor(name: string): Color3
	for _, stage in stages do
		if stage.Name == name then
			return stage.Color
		end
	end
	return Color3.new(1, 1, 1)
end

local function followCharacter()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

Remotes.EggLaunched.OnClientEvent:Connect(function(egg: BasePart, stageName: string)
	flying = true
	local color = stageColor(stageName)
	popText(stagePopup, popupScale, stageName .. "!", color, 0.9)
	if stageName == stages[1].Name or stageName == stages[2].Name then
		ringBurst(color)
	end
	if not egg then
		flying = false
		return
	end
	camera.CameraSubject = egg
	showDistanceBar(egg)
	-- The server removes the egg once it has hatched; then the camera comes home
	-- and the player can launch again.
	local done = false
	local connection: RBXScriptConnection
	local function finish()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		flying = false
		followCharacter()
	end
	connection = egg.AncestryChanged:Connect(function()
		if not egg:IsDescendantOf(workspace) then
			finish()
		end
	end)
	-- Backstop: if the removal never reaches this client (streaming, a dropped
	-- update), don't leave the player unable to launch again.
	task.delay(32, finish)
end)

Remotes.EggLanded.OnClientEvent:Connect(function(zoneIndex: number, _stageName: string, _distance: number)
	local zone = Config.Zones[zoneIndex]
	popText(zoneBanner, nil, "Landed in " .. zone.Name .. "!", zone.Color, 2)
	hideDistanceBar(1) -- out of the way before the hatch reveal starts
end)
