--!strict
-- The camera for a shot, and the impact frames on a Perfect.
--
-- While the meter bounces, the camera sits over your right shoulder, looking
-- down the lane past the bow. When you tap it swings round to your side to
-- show the shot animation; on the release it kicks; on a Perfect the
-- shot freezes for a moment (Config.Charge.PerfectFreeze) and flashes three
-- impact frames: a white flash, a stark black-and-white frame with burst lines,
-- then a gold one, before the view punches out and shakes.
--
-- The game's normal camera keeps running underneath: each frame this blends
-- from wherever it put the camera to the shot camera and back, so getting in
-- and out is smooth and the egg-follow camera takes over by itself.
-- It reads your charge from LocalCharge, which ChargeController writes.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local LocalCharge = require(script.Parent:WaitForChild("LocalCharge"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Where the shot camera sits, in the player's own space (+X right, +Y up, +Z
-- back; the player faces down the lane while drawing), and what it looks at.
local AIM_OFFSET = Vector3.new(2.2, 2.3, 8.5) -- over the right shoulder, so you stand left of the meter
local AIM_LOOK = Vector3.new(-0.8, 1.2, -40) -- down the lane, past the bow
local PUSH_IN = 1.6 -- studs closer at full draw
local NORMAL_FOV = 70
local FULL_DRAW_FOV = 58
local BLEND_IN = 0.22 -- seconds to get into the shot camera
local BLEND_OUT = 0.45 -- and back out after the release
local HOLD_AFTER_RELEASE = 0.35 -- stays on the shot a moment after the string lets go

-- The showcase: after you tap, the camera swings round from behind you to your
-- left side, a little in front, so you see the whole draw and release, drifting
-- slowly while you hold. It swings back behind the egg (the chase camera) once
-- the egg is away.
local SHOW_DELAY = 0.45 -- seconds after the tap, so you see "PERFECT!" first
local SHOW_SWING = 0.75 -- seconds to swing round
local SHOW_YAW = math.rad(-115) -- how far round (to your left and a bit in front)
local SHOW_DRIFT = math.rad(-12) -- extra slow drift during the hold
local SHOW_FOCUS = Vector3.new(0, 1.4, -0.6) -- what it looks at, in your own space

local PERFECT = Config.Charge.Stages[1].Name
local AMAZING = Config.Charge.Stages[2].Name

-- Chase camera (like Tmuk's reference): once the shot camera lets go, the view
-- rides low behind your egg as it flies down the lane, then looks down at it
-- from behind while it hatches.
local CHASE_BEHIND = Vector3.new(-20, 6, 0) -- from the egg, while flying (+X is down the lane)
local CHASE_LOOK = Vector3.new(40, -4, 0)
local LANDED_BEHIND = Vector3.new(-17, 10, 0) -- once it lands
local CHASE_BLEND = 0.35
local chaseEgg: BasePart? = nil
local chaseLanded = false
local chaseWeight = 0
local chaseFrame: CFrame? = nil

Remotes.EggLaunched.OnClientEvent:Connect(function(egg: BasePart?)
	chaseEgg = egg
	chaseLanded = false
	chaseFrame = nil
end)
Remotes.EggLanded.OnClientEvent:Connect(function()
	chaseLanded = true
end)

local weight = 0 -- 0 = the normal camera, 1 = the shot camera
local lastRelease = LocalCharge.releasedAt
local releaseHoldUntil = 0
local frozenAt: CFrame? = nil -- the camera during a Perfect's freeze
local kick = 0 -- forward push after a release, decays
local shake = 0 -- shake strength, decays
local fovPunch = 0 -- extra degrees of view, decays

--------------------------------------------------------------------------------
-- Impact frames
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ImpactFrames"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BorderSizePixel = 0
flash.BackgroundTransparency = 1
flash.Parent = gui

local LINE_COUNT = 30
local lines: { Frame } = {}
local lineHolder = Instance.new("Frame")
lineHolder.Name = "BurstLines"
lineHolder.Size = UDim2.fromScale(1, 1)
lineHolder.BackgroundTransparency = 1
lineHolder.Visible = false
lineHolder.ZIndex = 2
lineHolder.Parent = gui
for i = 1, LINE_COUNT do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BorderSizePixel = 0
	line.ZIndex = 2
	line.Parent = lineHolder
	lines[i] = line
end

-- Burst lines from the middle of the screen out past the edges, each a
-- slightly different length and width so it looks hand drawn.
local function layoutLines(color: Color3)
	local size = camera.ViewportSize
	local reach = size.Magnitude / 2
	for i, line in lines do
		local angle = (i / LINE_COUNT) * math.pi * 2 + math.random() * 0.15
		local inner = reach * (0.32 + math.random() * 0.18)
		local length = reach * 1.1 - inner
		local middle = inner + length / 2
		line.Position = UDim2.new(0.5, math.cos(angle) * middle, 0.5, math.sin(angle) * middle)
		line.Size = UDim2.fromOffset(length, 3 + math.random() * 9)
		line.Rotation = math.deg(angle)
		line.BackgroundColor3 = color
		line.BackgroundTransparency = 0
	end
end

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "ImpactFrameGrade"
grade.Enabled = false
grade.Parent = Lighting

local blur = Instance.new("BlurEffect")
blur.Name = "ImpactBlur"
blur.Size = 0
blur.Parent = Lighting

local function setGrade(brightness: number, contrast: number, saturation: number, tint: Color3)
	grade.Enabled = true
	grade.Brightness = brightness
	grade.Contrast = contrast
	grade.Saturation = saturation
	grade.TintColor = tint
end

local function clearFrames()
	flash.BackgroundTransparency = 1
	lineHolder.Visible = false
	grade.Enabled = false
end

local GOLD = Color3.fromRGB(255, 215, 60)

local function perfectImpact()
	local freeze = Config.Charge.PerfectFreeze
	local step = freeze / 3
	frozenAt = camera.CFrame
	-- 1: white flash with black burst lines
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.05
	layoutLines(Color3.new(0, 0, 0))
	lineHolder.Visible = true
	task.wait(step)
	-- 2: the world in stark black and white, white lines on a dark wash
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 0.55
	layoutLines(Color3.new(1, 1, 1))
	setGrade(0.15, 2.5, -1, Color3.new(1, 1, 1))
	task.wait(step)
	-- 3: gold
	flash.BackgroundColor3 = GOLD
	flash.BackgroundTransparency = 0.5
	layoutLines(GOLD)
	setGrade(0.1, 0.8, 0.3, Color3.fromRGB(255, 235, 170))
	task.wait(step)
	-- Out: the shot lets go with a punch, a shake and a quick blur.
	clearFrames()
	frozenAt = nil
	kick = 1
	shake = 1
	fovPunch = 22
	blur.Size = 16
	TweenService:Create(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 })
		:Play()
end

-- A softer pop for an Amazing.
local function amazingImpact()
	flash.BackgroundColor3 = Color3.fromRGB(255, 160, 220)
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	kick = 0.7
	shake = 0.45
	fovPunch = 10
end

local function onRelease(stage: string)
	releaseHoldUntil = os.clock() + HOLD_AFTER_RELEASE
	if stage == PERFECT then
		releaseHoldUntil += Config.Charge.PerfectFreeze
		-- The bow animation reaches its Impact frame about 0.05 s in.
		task.delay(0.05, perfectImpact)
	elseif stage == AMAZING then
		amazingImpact()
	else
		kick = 0.4
		shake = 0.15
		fovPunch = 5
	end
end

--------------------------------------------------------------------------------
-- Every frame, right after the normal camera has moved
--------------------------------------------------------------------------------

-- The showcase camera `since` seconds after the tap.
local function showcaseFrame(root: BasePart, since: number): CFrame
	local base = root.CFrame
	local swing = math.clamp((since - SHOW_DELAY) / SHOW_SWING, 0, 1)
	swing = swing * swing * (3 - 2 * swing)
	local drift = math.clamp((since - SHOW_DELAY - SHOW_SWING) / 2.5, 0, 1) * SHOW_DRIFT
	local yaw = SHOW_YAW * swing + drift
	local offset = CFrame.Angles(0, yaw, 0) * (AIM_OFFSET + Vector3.new(0, 0.4 * swing, -0.8 * swing))
	local position = base:PointToWorldSpace(offset)
	local lookAim = base:PointToWorldSpace(AIM_LOOK)
	local lookBody = base:PointToWorldSpace(SHOW_FOCUS)
	local frame = CFrame.lookAt(position, lookAim:Lerp(lookBody, swing))
	return frame + frame.LookVector * (kick * 1.2)
end

local function shotFrame(root: BasePart, meter: number): CFrame
	local base = root.CFrame
	local offset = AIM_OFFSET - Vector3.new(0, 0, PUSH_IN * meter)
	local position = base:PointToWorldSpace(offset)
	local look = base:PointToWorldSpace(AIM_LOOK)
	local frame = CFrame.lookAt(position, look)
	-- Pushes forward a little on the release.
	return frame + frame.LookVector * (kick * 1.2)
end

local function shakeOffset(now: number): CFrame
	if shake <= 0.001 then
		return CFrame.identity
	end
	local s = shake * 0.12
	return CFrame.Angles(
		math.noise(now * 30, 1.3) * s,
		math.noise(now * 30, 7.1) * s,
		math.noise(now * 30, 3.7) * s * 0.5
	)
end

RunService:BindToRenderStep("ShotCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local now = os.clock()
	if LocalCharge.releasedAt ~= lastRelease then
		lastRelease = LocalCharge.releasedAt
		onRelease(LocalCharge.releaseStage)
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- Showing the shot: from the tap until a moment after the string lets go.
	local released = LocalCharge.releasedAt >= LocalCharge.shotStartedAt
	local showing = LocalCharge.shooting and (not released or now < LocalCharge.releasedAt + HOLD_AFTER_RELEASE)
	local aiming = LocalCharge.charging or showing or now < releaseHoldUntil or frozenAt ~= nil
	local target = if aiming and root then 1 else 0
	local rate = if target > weight then dt / BLEND_IN else dt / BLEND_OUT
	weight = if target > weight then math.min(weight + rate, 1) else math.max(weight - rate, 0)

	local meter = 0
	if LocalCharge.charging then
		-- The string isn't drawn while the meter bounces (the draw is part of the
		-- shot animation), so the camera just sits a little closer.
		meter = 0.3
	elseif now < releaseHoldUntil or showing then
		meter = 0.4
	end

	-- Decay the release effects.
	kick = math.max(kick - dt * 3, 0)
	shake = math.max(shake - dt * 2.2, 0)
	fovPunch *= math.exp(-dt * 7)

	-- A little tremble while the string is drawn near the top.
	local tremble = if LocalCharge.charging then math.max(meter - 0.8, 0) * 0.25 else 0

	-- Chase camera underneath the shot camera.
	local egg = chaseEgg
	local chasing = egg ~= nil and egg:IsDescendantOf(workspace)
	chaseWeight = if chasing
		then math.min(chaseWeight + dt / CHASE_BLEND, 1)
		else math.max(chaseWeight - dt / CHASE_BLEND, 0)
	if chasing and egg then
		local at = egg.Position
		local goal = if chaseLanded
			then CFrame.lookAt(at + LANDED_BEHIND, at)
			else CFrame.lookAt(at + CHASE_BEHIND, at + CHASE_LOOK)
		-- Smoothed, so the egg's bounces don't shake the view.
		chaseFrame = if chaseFrame then chaseFrame:Lerp(goal, 1 - math.exp(-dt * 10)) else goal
	elseif not chasing and chaseWeight <= 0 then
		chaseFrame = nil
	end
	if chaseFrame and chaseWeight > 0 then
		local c = chaseWeight * chaseWeight * (3 - 2 * chaseWeight)
		camera.CFrame = camera.CFrame:Lerp(chaseFrame, c)
	end

	if frozenAt then
		camera.CFrame = frozenAt
	elseif weight > 0 and root and root:IsA("BasePart") then
		local eased = weight * weight * (3 - 2 * weight)
		local shot = if LocalCharge.shooting
			then showcaseFrame(root, now - LocalCharge.shotStartedAt)
			else shotFrame(root, meter)
		camera.CFrame = camera.CFrame:Lerp(shot, eased) * shakeOffset(now)
		if tremble > 0 then
			local t = tremble * 0.02
			camera.CFrame *= CFrame.Angles(math.noise(now * 18, 2.2) * t, math.noise(now * 18, 5.5) * t, 0)
		end
	elseif shake > 0 then
		camera.CFrame *= shakeOffset(now)
	end

	local drawFov = NORMAL_FOV + (FULL_DRAW_FOV - NORMAL_FOV) * meter
	local eased = weight * weight * (3 - 2 * weight)
	camera.FieldOfView = NORMAL_FOV + (drawFov - NORMAL_FOV) * eased + fovPunch
end)
