--!strict
-- Launch controls: while the slingshot is in hand and you're in the hub, hold the
-- big launch button (or click and hold, or the E key on PC). Also draws the
-- bouncing charge meter, the slingshot band pulling back and snapping,
-- the stage word that pops up on release (with a ring burst for the best ones),
-- a camera that follows the egg, and a banner naming the zone it lands in.
-- The hatch itself is in HatchController.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Charge = require(Shared.Charge)
local Lane = require(Shared.Lane)
local Remotes = require(Shared.Remotes)
local SlingshotModel = require(Shared.SlingshotModel)

local LocalCharge = require(script.Parent:WaitForChild("LocalCharge"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FONT = Enum.Font.FredokaOne
local LAUNCH_KEY = Enum.KeyCode.E

local NORMAL_FOV = 70
local CHARGE_FOV = 80 -- the camera pulls back a little while charging

local charging = false
local chargeStart = 0
local flying = false
local chargeInput: InputObject? = nil -- the touch, click or key that started the charge
local chargedByTool = false -- started by Tool.Activated instead
local lockedHumanoid: Humanoid? = nil -- turned to face the lane while charging

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

-- Vertical meter on the right: a framed bar whose colours blend from Poor at
-- the bottom to Perfect at the top, with faint lines where the stages meet.
local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.AnchorPoint = Vector2.new(1, 0.5)
meter.Position = UDim2.new(1, -220, 0.5, 0)
meter.Size = UDim2.fromOffset(60, 330)
meter.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
meter.Visible = false
meter.Parent = gui
corner(meter, UDim.new(0, 18))
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.new(1, 1, 1)
frameStroke.Thickness = 4
frameStroke.Parent = meter

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.fromScale(0.5, 0.5)
bar.Size = UDim2.new(1, -18, 1, -18)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.Parent = meter
corner(bar, UDim.new(0, 10))
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(20, 20, 30)
barStroke.Thickness = 2
barStroke.Parent = bar

-- On phones, keep the button and meter clear of the jump button, which sits
-- within about 230 px of the bottom-right corner in every layout.
if UserInputService.TouchEnabled then
	button.Position = UDim2.new(1, -240, 1, -30)
	meter.AnchorPoint = Vector2.new(1, 1)
	meter.Position = UDim2.new(1, -410, 1, -30)
end

local stages = Config.Charge.Stages

-- Each stage's colour sits at the middle of its band, and the gradient blends between them.
local keypoints = { ColorSequenceKeypoint.new(0, stages[#stages].Color) }
for i = #stages, 1, -1 do
	local stage = stages[i]
	local top = if i == 1 then 1 else stages[i - 1].Min
	table.insert(keypoints, ColorSequenceKeypoint.new((stage.Min + top) / 2, stage.Color))
	if stage.Min > 0 then
		local line = Instance.new("Frame")
		line.Name = stage.Name .. "Line"
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Position = UDim2.fromScale(0, 1 - stage.Min)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.5
		line.Parent = bar
	end
end
table.insert(keypoints, ColorSequenceKeypoint.new(1, stages[1].Color))
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(keypoints)
gradient.Rotation = -90 -- 0 at the bottom, 1 at the top, like the needle
gradient.Parent = bar

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Size = UDim2.new(1, 22, 0, 10)
needle.BackgroundColor3 = Color3.new(1, 1, 1)
needle.ZIndex = 2
needle.Parent = bar
local needleStroke = Instance.new("UIStroke")
needleStroke.Color = Color3.fromRGB(20, 20, 30)
needleStroke.Thickness = 2
needleStroke.Parent = needle
corner(needle, UDim.new(1, 0))

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
end

-- Hides the bar a moment after landing, unless a new egg is already flying.
local function hideDistanceBar(after: number)
	local egg = trackedEgg
	task.delay(after, function()
		if trackedEgg == egg then
			trackedEgg = nil
			distanceBar.Visible = false
		end
	end)
end

RunService.RenderStepped:Connect(function()
	local egg = trackedEgg
	if egg and egg.Parent then
		setDistanceBar((egg.Position.X - Config.Lane.StartX) / Lane.Length)
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
		and Lane.isInHub(root.Position)
end

-- Turns the character to face down the lane (where the egg flies) and holds
-- that facing until the charge ends.
local function faceLane()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.xAxis)
	end
	if humanoid then
		humanoid.AutoRotate = false
		lockedHumanoid = humanoid
	end
end

local function startCharge(input: InputObject?)
	if charging or flying or not canLaunch() then
		return
	end
	charging = true
	chargeInput = input
	chargedByTool = input == nil
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
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { FieldOfView = CHARGE_FOV }):Play()
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	chargeInput = nil
	chargedByTool = false
	LocalCharge.charging = false
	LocalCharge.releasedAt = os.clock()
	LocalCharge.releasePull = pull.Value
	if lockedHumanoid then
		lockedHumanoid.AutoRotate = true
		lockedHumanoid = nil
	end
	Remotes.ChargeRelease:FireServer()
	local tween = TweenService:Create(pull, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = 0 })
	snapTween = tween
	tween:Play()
	TweenService:Create(buttonScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Back), { FieldOfView = NORMAL_FOV }):Play()
	task.delay(0.4, function()
		if not charging then
			meter.Visible = false
		end
	end)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

button.InputBegan:Connect(function(input)
	if isPress(input) then
		startCharge(input)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == LAUNCH_KEY then
		startCharge(input)
	end
end)

-- Letting go anywhere on screen counts, so sliding a finger off the button still
-- launches. On touch screens only the finger that started the charge counts, so
-- moving or jumping with another finger doesn't fire the egg.
UserInputService.InputEnded:Connect(function(input: InputObject)
	if not charging or chargedByTool then
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
		startCharge(nil)
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
	button.Visible = (charging or not flying) and ready
	if charging and not ready then
		-- Put away or walked off the hub mid-charge: let go.
		releaseCharge()
	end
	if charging then
		local value = Charge.valueAt(os.clock() - chargeStart)
		needle.Position = UDim2.fromScale(0.5, 1 - value)
		needle.BackgroundColor3 = Charge.stageFor(value).Color
		pull.Value = value
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
	hideDistanceBar(2.5)
end)
