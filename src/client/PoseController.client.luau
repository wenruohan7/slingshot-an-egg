--!strict
-- Poses every player's character for a bow shot. While the meter bounces you
-- just stand holding the bow; when you tap, one of the shot animations plays
-- (ShotAnimations: BowShot1 70% of the time, BowShot2 30%): lift the bow, draw
-- slowly, hold, release at ReleaseAt (when the egg leaves), follow through.
-- The string follows the shot's Pull curve, then snaps forward.
--
-- With the animations available (uploaded ids in Config.Slingshot, or in Studio
-- straight from ReplicatedStorage.BowAnimations) your own character plays them,
-- and once uploaded everyone sees them. Without them, the arms are posed from
-- code instead, so nothing has to be uploaded to play. Each client poses
-- everyone: your own character from LocalCharge (no lag), other players from
-- the ShotName / ShotStartedAt attributes the server puts on their character.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local ShotAnimations = require(Shared.ShotAnimations)
local SlingshotModel = require(Shared.SlingshotModel)
local LocalCharge = require(script.Parent:WaitForChild("LocalCharge"))

local player = Players.LocalPlayer

local BLEND_IN = 0.3 -- seconds to ease into the pose
local LEAN_BACK = math.rad(10) -- at full draw
local LEAN_FORWARD = math.rad(14) -- the lunge on release
local LUNGE_TIME = 0.45
local SETTLE_TIME = 0.8 -- after the release the pose has faded out by then (code poses)

local shotsByName: { [string]: ShotAnimations.Shot } = {}
for _, shot in ShotAnimations do
	shotsByName[shot.Name] = shot
end

type Pose = {
	weight: number, -- 0 = normal animations, 1 = fully posed
	band: number, -- how far back the string is (below 0 overshoots forward)
	lean: number, -- radians, + is back
	spin: number, -- radians the whole body has turned (follow-through)
}

-- The string's draw `t` seconds into a shot, before the release.
local function pullAt(shot: ShotAnimations.Shot, t: number): number
	local keys = shot.Pull
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local f = (t - a[1]) / math.max(b[1] - a[1], 1e-3)
			f = f * f * (3 - 2 * f)
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return keys[#keys][2]
end

-- The pose `since` seconds into a shot, or nil once it's over.
local function shotPose(shot: ShotAnimations.Shot, since: number): Pose?
	if since < 0 or since >= shot.Length then
		return nil
	end
	local spin = 0
	if shot.Spin then
		local spinT = math.clamp((since - shot.Spin[1]) / shot.Spin[2], 0, 1)
		spin = math.pi * 2 * (1 - (1 - spinT) ^ 3)
	end
	if since < shot.ReleaseAt then
		local draw = pullAt(shot, since)
		return {
			weight = math.min(since / BLEND_IN, 1),
			band = draw,
			lean = LEAN_BACK * math.max(draw - 0.6, 0) / 0.4,
			spin = spin,
		}
	end
	local after = since - shot.ReleaseAt
	local lunge = math.sin(math.pi * math.min(after / LUNGE_TIME, 1))
	local fade = shot.Length - shot.ReleaseAt
	local settle = math.min(SETTLE_TIME, fade)
	return {
		weight = if after < LUNGE_TIME then 1 else math.max(1 - (after - LUNGE_TIME) / math.max(settle - LUNGE_TIME, 0.1), 0),
		band = math.exp(-7 * after) * math.cos(20 * after),
		lean = LEAN_BACK * math.exp(-12 * after) - LEAN_FORWARD * lunge,
		spin = spin,
	}
end

-- The shot this character is doing and how far into it, or nil.
local function currentShot(character: Model, isLocal: boolean): (ShotAnimations.Shot?, number)
	if isLocal then
		if LocalCharge.shooting then
			return shotsByName[LocalCharge.shotName], os.clock() - LocalCharge.shotStartedAt
		end
		return nil, 0
	end
	local name = character:GetAttribute("ShotName")
	local startedAt = character:GetAttribute("ShotStartedAt")
	if typeof(name) == "string" and typeof(startedAt) == "number" then
		return shotsByName[name], workspace:GetServerTimeNow() - startedAt
	end
	return nil, 0
end

local function poseFor(character: Model, isLocal: boolean): Pose?
	local shot, since = currentShot(character, isLocal)
	if shot then
		return shotPose(shot, since)
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

type Joints = { shoulder: Motor6D?, elbow: Motor6D?, waist: Motor6D?, root: Motor6D? }

local function jointsOf(character: Model): Joints
	local torso = character:FindFirstChild("Torso")
	if torso then -- R6
		return {
			shoulder = motor(torso, "Left Shoulder"),
			elbow = nil,
			waist = motor(character:FindFirstChild("HumanoidRootPart"), "RootJoint"),
			root = motor(character:FindFirstChild("HumanoidRootPart"), "RootJoint"),
		}
	end
	return {
		shoulder = motor(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"),
		elbow = motor(character:FindFirstChild("LeftLowerArm"), "LeftElbow"),
		waist = motor(character:FindFirstChild("UpperTorso"), "Waist"),
		root = motor(character:FindFirstChild("LowerTorso"), "Root"),
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

-- Turns the whole body around the up axis by turning the root joint's C0 (its
-- Transform is the animations' to set). The original C0 is kept and put back.
local originalC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function applySpin(character: Model, spin: number)
	local root = jointsOf(character).root
	if not root then
		return
	end
	local base = originalC0[root]
	if spin <= 0 or spin >= math.pi * 2 - 1e-3 then
		if base then
			root.C0 = base
			originalC0[root] = nil
		end
		return
	end
	if not base then
		base = root.C0
		originalC0[root] = base
	end
	root.C0 = CFrame.Angles(0, spin, 0) * base
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
-- The bow animations
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PERFECT = Config.Charge.Stages[1].Name

local function configuredId(name: string): string
	local id = Config.Slingshot.ShotAnimationIds[name]
	return if typeof(id) == "string" then id else ""
end

-- Whether every shot has an uploaded id (then everyone sees them).
local uploaded = true
for _, shot in ShotAnimations do
	if configuredId(shot.Name) == "" then
		uploaded = false
	end
end

-- The animation id to use: the uploaded one, or in Studio a temporary id for the
-- KeyframeSequence in ReplicatedStorage.BowAnimations (Studio-only, so you can try
-- them before uploading).
local function animationId(name: string): string?
	local configured = configuredId(name)
	if configured ~= "" then
		return configured
	end
	if not RunService:IsStudio() then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("BowAnimations")
	local sequence = folder and folder:FindFirstChild(name)
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		return nil
	end
	local ok, id = pcall(function()
		return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(sequence)
	end)
	return if ok then id else nil
end

local shotIds: { [string]: string } = {}
local useOwnAnimations = true
for _, shot in ShotAnimations do
	local id = animationId(shot.Name)
	if id then
		shotIds[shot.Name] = id
	else
		useOwnAnimations = false
	end
end

type Tracks = { animator: Animator, byName: { [string]: AnimationTrack } }
local tracks: Tracks? = nil

-- The tracks for your current character (loaded again after a respawn).
local function ownTracks(): Tracks?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	if tracks and tracks.animator == animator then
		return tracks
	end
	local byName = {}
	for name, id in shotIds do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action2
		track.Looped = false
		-- Impact: hold still for a Perfect (the hit-stop under the impact frames).
		track:GetMarkerReachedSignal("Impact"):Connect(function()
			if LocalCharge.releaseStage == PERFECT then
				track:AdjustSpeed(0)
				task.delay(Config.Charge.PerfectFreeze, function()
					if track.IsPlaying then
						track:AdjustSpeed(1)
					end
				end)
			end
		end)
		-- Done: ease back into the normal animations.
		track:GetMarkerReachedSignal("Done"):Connect(function()
			track:Stop(0.45)
		end)
		byName[name] = track
	end
	local loaded = { animator = animator, byName = byName }
	tracks = loaded
	return loaded
end

local playingShotAt = -math.huge

local function updateOwnAnimations()
	local t = ownTracks()
	if not t then
		return
	end
	if LocalCharge.shooting and LocalCharge.shotStartedAt ~= playingShotAt then
		playingShotAt = LocalCharge.shotStartedAt
		for _, track in t.byName do
			track:Stop(0.1)
		end
		local track = t.byName[LocalCharge.shotName]
		if track then
			track:Play(0.2, 1, 1)
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
		-- Animations replicate only once uploaded; the Studio-only ones are just yours.
		local animated = if isLocal then useOwnAnimations else uploaded
		local pose = poseFor(character, isLocal)
		local tool = character:FindFirstChild(SlingshotModel.NAME)
		local slingshot = if tool and tool:IsA("Tool") then tool else nil
		if pose then
			posed[character] = true
			if not animated then
				applyPose(character, pose, slingshot)
				applySpin(character, pose.spin)
			end
			if slingshot then
				SlingshotModel.setPull(slingshot, pose.band)
			end
		elseif posed[character] then
			posed[character] = nil
			applySpin(character, 0)
			if not animated then
				clearPose(character)
			end
			if slingshot then
				SlingshotModel.setPull(slingshot, 0)
			end
		end
	end
end)
