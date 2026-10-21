--!strict
-- Handles the launch: the client says when the button went down and up,
-- and the server works out the charge stage from its own timing, so a
-- client can't just claim "Perfect". Then it flies the egg down the lane
-- and reports which zone it landed in.

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Charge = require(Shared.Charge)
local Lane = require(Shared.Lane)
local Remotes = require(Shared.Remotes)
local SlingshotModel = require(Shared.SlingshotModel)
local PlotService = require(script.Parent.PlotService)

local LaunchService = {}

local GROUND_Y = 2 -- egg rests on the lane surface (y = 0) with its centre 2 studs up
local EGG_COLOR = Color3.fromRGB(255, 250, 235)
local EGG_LIFETIME = 4 -- seconds the egg sits after landing (hatching comes in step 3)

local chargeStarted: { [Player]: number } = {}
local inFlight: { [Player]: boolean } = {}

local function launchPad(player: Player): BasePart?
	local index = PlotService.getPlotIndex(player)
	if not index then
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local pad = hub and hub:FindFirstChild("LaunchPad" .. index)
	if pad and pad:IsA("BasePart") then
		return pad
	end
	return nil
end

local function isNearPad(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = root.Position - pad.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Slingshot.LaunchRange
end

function LaunchService.launchPower(player: Player): number
	local level = (player:GetAttribute("SlingshotLevel") :: number?) or 0
	return Config.Slingshot.BasePower * Config.Slingshot.LevelGrowth ^ level
end

local function makeEgg(position: Vector3): Part
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(4, 4, 4)
	egg.Color = EGG_COLOR
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = false
	egg.Position = position

	-- Stretch the ball into an egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = egg

	-- Flights go past the default streaming radius, so keep the egg loaded on clients.
	local holder = Instance.new("Model")
	holder.Name = "EggFlight"
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	egg.Parent = holder
	holder.Parent = workspace
	return egg
end

-- Moves the egg along an arc from `from` to `to`, then calls `onLanded`.
local function flyEgg(egg: Part, from: Vector3, to: Vector3, onLanded: () -> ())
	local distance = (to - from).Magnitude
	local duration = 1.2 + distance / 500
	local arcHeight = 20 + distance * 0.15
	local elapsed = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / duration, 1)
		local position = from:Lerp(to, t) + Vector3.new(0, arcHeight * 4 * t * (1 - t), 0)
		egg.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, -t * math.pi * 6)
		if t >= 1 then
			connection:Disconnect()
			egg.CFrame = CFrame.new(to)
			onLanded()
		end
	end)
end

local function onChargeStart(player: Player)
	if inFlight[player] then
		return
	end
	chargeStarted[player] = os.clock()
end

local function onChargeRelease(player: Player)
	local started = chargeStarted[player]
	chargeStarted[player] = nil
	if not started or inFlight[player] then
		return
	end

	local pad = launchPad(player)
	if not pad or not isNearPad(player, pad) then
		return
	end

	local stage = Charge.stageFor(Charge.valueAt(os.clock() - started))
	local distance = math.min(LaunchService.launchPower(player) * stage.Power, Lane.Length - 1)
	local zoneIndex = Lane.zoneAt(distance)

	local slingshot = pad:FindFirstChild("Slingshot")
	local from = if slingshot and slingshot:IsA("Model")
		then SlingshotModel.pouchPosition(slingshot)
		else pad.Position + Vector3.new(4, 8, 0)
	local to = Vector3.new(Config.Lane.StartX + distance, GROUND_Y, pad.Position.Z)

	inFlight[player] = true
	local egg = makeEgg(from)
	Remotes.EggLaunched:FireClient(player, egg, stage.Name)

	flyEgg(egg, from, to, function()
		Remotes.EggLanded:FireClient(player, zoneIndex, stage.Name, distance)
		task.delay(EGG_LIFETIME, function()
			local holder = egg.Parent or egg
			holder:Destroy()
			inFlight[player] = nil
		end)
	end)
end

function LaunchService.init()
	Remotes.ChargeStart.OnServerEvent:Connect(onChargeStart)
	Remotes.ChargeRelease.OnServerEvent:Connect(onChargeRelease)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		chargeStarted[player] = nil
		inFlight[player] = nil
	end)
end

return LaunchService
