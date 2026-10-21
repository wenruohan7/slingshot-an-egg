--!strict
-- Launch controls: while the slingshot is in hand and you're in the hub, hold the
-- big launch button (or click and hold, or the E key on PC). Also draws the
-- bouncing charge meter, the slingshot band pulling back and snapping,
-- the stage word that pops up on release,
-- a camera that follows the egg, and a banner naming the zone it lands in.

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

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FONT = Enum.Font.FredokaOne
local LAUNCH_KEY = Enum.KeyCode.E

local charging = false
local chargeStart = 0
local flying = false

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

-- Vertical meter on the right, one coloured band per stage.
local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.AnchorPoint = Vector2.new(1, 0.5)
meter.Position = UDim2.new(1, -220, 0.5, 0)
meter.Size = UDim2.fromOffset(40, 300)
meter.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
meter.Visible = false
meter.Parent = gui
corner(meter, UDim.new(0, 12))

local stages = Config.Charge.Stages
for i, stage in stages do
	local top = if i == 1 then 1 else stages[i - 1].Min
	local band = Instance.new("Frame")
	band.Name = stage.Name
	band.BorderSizePixel = 0
	band.BackgroundColor3 = stage.Color
	band.Position = UDim2.fromScale(0, 1 - top)
	band.Size = UDim2.fromScale(1, top - stage.Min)
	band.Parent = meter
end

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Size = UDim2.new(1, 16, 0, 8)
needle.BackgroundColor3 = Color3.new(1, 1, 1)
needle.ZIndex = 2
needle.Parent = meter
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

local zoneBanner = label({
	Name = "ZoneBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(520, 70),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})

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

pull.Changed:Connect(function(value)
	local slingshot = heldSlingshot()
	if slingshot then
		SlingshotModel.setPull(slingshot, value)
	end
end)

local function canLaunch(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return heldSlingshot() ~= nil and root ~= nil and root:IsA("BasePart") and Lane.isInHub(root.Position)
end

local function startCharge()
	if charging or flying or not canLaunch() then
		return
	end
	charging = true
	chargeStart = os.clock()
	if snapTween then
		snapTween:Cancel()
		snapTween = nil
	end
	meter.Visible = true
	Remotes.ChargeStart:FireServer()
	TweenService:Create(buttonScale, TweenInfo.new(0.15), { Scale = 0.88 }):Play()
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	Remotes.ChargeRelease:FireServer()
	snapTween = TweenService:Create(pull, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = 0 })
	snapTween:Play()
	TweenService:Create(buttonScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
		startCharge()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == LAUNCH_KEY then
		startCharge()
	end
end)

-- Release anywhere on screen counts, so sliding a finger off the button still launches.
UserInputService.InputEnded:Connect(function(input)
	if isPress(input) or input.KeyCode == LAUNCH_KEY then
		releaseCharge()
	end
end)

-- Clicking and holding with the slingshot in hand works too (and tapping on mobile).
local hookedTool: Tool? = nil
local function hookTool(tool: Tool?)
	if tool == nil or tool == hookedTool then
		return
	end
	hookedTool = tool
	tool.Activated:Connect(startCharge)
	tool.Deactivated:Connect(releaseCharge)
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
	popText(stagePopup, popupScale, stageName .. "!", stageColor(stageName), 0.9)
	if not egg then
		flying = false
		return
	end
	camera.CameraSubject = egg
	-- The server removes the egg a few seconds after landing; then the player can launch again.
	egg.AncestryChanged:Connect(function()
		if not egg:IsDescendantOf(workspace) then
			flying = false
		end
	end)
end)

Remotes.EggLanded.OnClientEvent:Connect(function(zoneIndex: number, _stageName: string, _distance: number)
	local zone = Config.Zones[zoneIndex]
	popText(zoneBanner, nil, "Landed in " .. zone.Name .. "!", zone.Color, 2)
	task.delay(1.5, followCharacter)
end)
