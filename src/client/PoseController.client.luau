--!strict
-- Poses every player's character while they use the slingshot: the free arm
-- reaches for the pouch and follows it back as the meter fills, the body leans
-- back, then on release the arm springs forward with the band and the body
-- lunges after it. Works on R15 and R6 characters.
--
-- It's done from code on top of the normal animations, so nothing has to be
-- uploaded. Each client poses everyone: your own character from LocalCharge
-- (no lag), other players from the attributes the server puts on their
-- character. If Config.Slingshot.ChargeAnimationId is set, your own Animation
-- Editor animations play instead.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Charge = require(Shared.Charge)
local SlingshotModel = require(Shared.SlingshotModel)
local LocalCharge = require(script.Parent:WaitForChild("LocalCharge"))

local player = Players.LocalPlayer

local BLEND_IN = 0.15 -- seconds to ease into the pose
local LEAN_BACK = math.rad(10) -- at full pull
local LEAN_FORWARD = math.rad(14) -- the lunge on release
local LUNGE_TIME = 0.45
local RELEASE_TIME = 0.8 -- the pose has faded out by then

type Pose = {
	weight: number, -- 0 = normal animations, 1 = fully posed
	band: number, -- how far back the band is (below 0 overshoots forward)
	lean: number, -- radians, + is back
}

-- The pose for this point in a charge (held = seconds held).
local function chargingPose(held: number): Pose
	local pull = Charge.valueAt(held)
	return { weight = math.min(held / BLEND_IN, 1), band = pull, lean = LEAN_BACK * pull }
end

-- The pose `since` seconds after letting go at `pull`, or nil once it's over.
local function releasePose(since: number, pull: number): Pose?
	if since < 0 or since >= RELEASE_TIME then
		return nil
	end
	local lunge = math.sin(math.pi * math.min(since / LUNGE_TIME, 1))
	return {
		weight = if since < LUNGE_TIME then 1 else 1 - (since - LUNGE_TIME) / (RELEASE_TIME - LUNGE_TIME),
		band = pull * math.exp(-7 * since) * math.cos(20 * since),
		lean = LEAN_BACK * pull * math.exp(-12 * since) - LEAN_FORWARD * lunge,
	}
end

local function poseFor(character: Model, isLocal: boolean): Pose?
	if isLocal then
		if LocalCharge.charging then
			return chargingPose(os.clock() - LocalCharge.startedAt)
		end
		return releasePose(os.clock() - LocalCharge.releasedAt, LocalCharge.releasePull)
	end
	local now = workspace:GetServerTimeNow()
	local startedAt = character:GetAttribute("ChargeStartedAt")
	if typeof(startedAt) == "number" then
		return chargingPose(now - startedAt)
	end
	local launchedAt = character:GetAttribute("LaunchedAt")
	local launchPull = character:GetAttribute("LaunchPull")
	if typeof(launchedAt) == "number" and typeof(launchPull) == "number" then
		return releasePose(now - launchedAt, launchPull)
	end
	return nil
end

--------------------------------------------------------------------------------
-- Joints
--------------------------------------------------------------------------------

local function motor(parent: Instance?, name: string): Motor6D?
	local found = parent and parent:FindFirstChild(name)
	return if found and found:IsA("Motor6D") then found else nil
end

type Joints = { shoulder: Motor6D?, elbow: Motor6D?, waist: Motor6D? }

local function jointsOf(character: Model): Joints
	local torso = character:FindFirstChild("Torso")
	if torso then -- R6
		return {
			shoulder = motor(torso, "Left Shoulder"),
			elbow = nil,
			waist = motor(character:FindFirstChild("HumanoidRootPart"), "RootJoint"),
		}
	end
	return {
		shoulder = motor(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"),
		elbow = motor(character:FindFirstChild("LeftLowerArm"), "LeftElbow"),
		waist = motor(character:FindFirstChild("UpperTorso"), "Waist"),
	}
end

-- The Transform that turns a joint's limb by `rotation`, measured in the space
-- of the part it hangs from (Part1 = Part0 * C0 * Transform * C1:Inverse()).
local function transformFor(joint: Motor6D, rotation: CFrame): CFrame
	return joint.C0.Rotation:Inverse() * rotation * joint.C1.Rotation
end

-- A limb rotation that points the limb's bottom end along `direction`.
local function pointing(direction: Vector3): CFrame
	local up = -direction.Unit
	local right = Vector3.xAxis - up * up:Dot(Vector3.xAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.zAxis
	end
	return CFrame.fromMatrix(Vector3.zero, right.Unit, up)
end

-- Where the free hand reaches: the pouch, or above the handle on a custom model.
local function handTarget(tool: Tool?): Vector3?
	if not tool then
		return nil
	end
	local pouch = tool:FindFirstChild("Pouch")
	if pouch and pouch:IsA("BasePart") then
		return pouch.Position
	end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle.Position + Vector3.new(0, 2, 0)
	end
	return nil
end

local function blend(joint: Motor6D?, target: CFrame, weight: number)
	if joint then
		joint.Transform = joint.Transform:Lerp(target, weight)
	end
end

local function applyPose(character: Model, pose: Pose, tool: Tool?)
	local joints = jointsOf(character)
	local w = math.clamp(pose.weight, 0, 1)
	if joints.waist then
		blend(joints.waist, transformFor(joints.waist, CFrame.Angles(pose.lean, 0, 0)), w)
	end
	local shoulder = joints.shoulder
	local target = handTarget(tool)
	local torso = shoulder and shoulder.Part0
	if shoulder and torso and target then
		local jointPosition = (torso.CFrame * shoulder.C0).Position
		local direction = torso.CFrame:VectorToObjectSpace(target - jointPosition)
		if direction.Magnitude > 1e-3 then
			blend(shoulder, transformFor(shoulder, pointing(direction)), w)
		end
	end
	-- Keep the arm straight so the hand reaches as far as it can.
	blend(joints.elbow, CFrame.identity, w)
end

-- Puts the joints back once a pose ends, in case no animation resets them.
local function clearPose(character: Model)
	local joints = jointsOf(character)
	for _, joint in { joints.shoulder, joints.elbow, joints.waist } do
		if joint then
			joint.Transform = CFrame.identity
		end
	end
end

--------------------------------------------------------------------------------
-- Your own animations, if Config names them
--------------------------------------------------------------------------------

local useOwnAnimations = Config.Slingshot.ChargeAnimationId ~= ""
local chargeTrack: AnimationTrack? = nil
local wasCharging = false

local function loadTrack(id: string): AnimationTrack?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if id == "" or not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

-- Tracks played on your own character show for everyone without extra work.
local function updateOwnAnimations()
	if LocalCharge.charging == wasCharging then
		return
	end
	wasCharging = LocalCharge.charging
	if wasCharging then
		chargeTrack = loadTrack(Config.Slingshot.ChargeAnimationId)
		if chargeTrack then
			chargeTrack:Play(BLEND_IN)
		end
	else
		if chargeTrack then
			chargeTrack:Stop(0.1)
			chargeTrack = nil
		end
		local launchTrack = loadTrack(Config.Slingshot.LaunchAnimationId)
		if launchTrack then
			launchTrack:Play(0.05)
		end
	end
end

--------------------------------------------------------------------------------
-- Every frame, after the normal animations and before physics
--------------------------------------------------------------------------------

local posed: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

RunService.PreSimulation:Connect(function()
	if useOwnAnimations then
		updateOwnAnimations()
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character then
			continue
		end
		local isLocal = other == player
		local pose = poseFor(character, isLocal)
		local tool = character:FindFirstChild(SlingshotModel.NAME)
		local slingshot = if tool and tool:IsA("Tool") then tool else nil
		if pose then
			posed[character] = true
			if not useOwnAnimations then
				applyPose(character, pose, slingshot)
			end
			-- Your own band is driven by ChargeController; other players' bands here.
			if slingshot and not isLocal then
				SlingshotModel.setPull(slingshot, pose.band)
			end
		elseif posed[character] then
			posed[character] = nil
			if not useOwnAnimations then
				clearPose(character)
			end
			if slingshot and not isLocal then
				SlingshotModel.setPull(slingshot, 0)
			end
		end
	end
end)
