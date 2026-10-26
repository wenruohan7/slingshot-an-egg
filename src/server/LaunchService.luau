--!strict
-- Handles the launch: the client says when the button went down and up,
-- and the server works out the charge stage from its own timing, so a
-- client can't just claim "Perfect". Then it flies the egg from the player's
-- slingshot down the lane, reports which zone it landed in, and hatches it.
-- Players can launch from anywhere on the hub floor while holding the slingshot.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Charge = require(Shared.Charge)
local Economy = require(Shared.Economy)
local Lane = require(Shared.Lane)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)
local SlingshotModel = require(Shared.SlingshotModel)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local HatchService = require(script.Parent.HatchService)
local PlotService = require(script.Parent.PlotService)

local LaunchService = {}

local GROUND_Y = 2 -- egg rests on the lane surface (y = 0) with its centre 2 studs up
local EGG_COLOR = Color3.fromRGB(255, 250, 235)
local BOUNCE_SECONDS = 0.5 -- two little hops after touching down
local LANE_EDGE_MARGIN = 10 -- keep landings this far inside the lane's sides

local chargeStarted: { [Player]: number } = {}
local inFlight: { [Player]: boolean } = {}

-- The player's root part, if they are alive, holding the slingshot, standing in
-- the hub and their data has loaded.
local function launchingRoot(player: Player): BasePart?
	local character = player.Character
	local tool = character and character:FindFirstChild(SlingshotModel.NAME)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		tool
		and tool:IsA("Tool")
		and humanoid
		and humanoid.Health > 0
		and root
		and root:IsA("BasePart")
		and Lane.isInHub(root.Position)
		and DataService.get(player)
	then
		return root
	end
	return nil
end

function LaunchService.launchPower(player: Player): number
	local data = DataService.get(player)
	return Economy.launchPower(if data then data.SlingshotLevel else 0)
end

local function makeEgg(position: Vector3, trailColor: Color3): Part
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

	-- A colour trail in the stage's colour. The attachments sit on the spin axis
	-- so the ribbon stays flat while the egg tumbles.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -1.2)
	a0.Parent = egg
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 1.2)
	a1.Parent = egg
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(trailColor)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.5
	trail.LightEmission = 0.6
	trail.Parent = egg

	-- Flights go past the default streaming radius, so keep the egg loaded on clients.
	local holder = Instance.new("Model")
	holder.Name = "EggFlight"
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	egg.Parent = holder
	holder.Parent = workspace
	return egg
end

-- Moves the egg along an arc from `from` to `to`, gives it two little hops on
-- the spot, then calls `onLanded`.
local function flyEgg(egg: Part, from: Vector3, to: Vector3, onLanded: () -> ())
	local distance = (to - from).Magnitude
	local duration = 1.2 + distance / 500
	local arcHeight = 20 + distance * 0.15
	local elapsed = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < duration then
			local t = elapsed / duration
			local position = from:Lerp(to, t) + Vector3.new(0, arcHeight * 4 * t * (1 - t), 0)
			egg.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, -t * math.pi * 6)
			return
		end
		-- Hops: a 3-stud one, then a 1-stud one.
		local b = (elapsed - duration) / BOUNCE_SECONDS
		if b < 1 then
			local hop = if b < 0.6 then 3 * math.sin(b / 0.6 * math.pi) else 1 * math.sin((b - 0.6) / 0.4 * math.pi)
			egg.CFrame = CFrame.new(to + Vector3.new(0, hop, 0))
			return
		end
		connection:Disconnect()
		egg.CFrame = CFrame.new(to)
		onLanded()
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

	local root = launchingRoot(player)
	if not root then
		return
	end

	local stage = Charge.stageFor(Charge.valueAt(os.clock() - started))
	local distance = math.min(LaunchService.launchPower(player) * stage.Power, Lane.Length - 1)
	local zoneIndex = Lane.zoneAt(distance)

	-- Launch from the slingshot's pouch, and land in line with the player.
	local character = root.Parent :: Instance
	local tool = character:FindFirstChild(SlingshotModel.NAME)
	local pouch = tool and tool:FindFirstChild("Pouch")
	local from = if pouch and pouch:IsA("BasePart") then pouch.Position else root.Position + Vector3.new(0, 3, 0)
	local laneHalf = Config.Lane.Width / 2 - LANE_EDGE_MARGIN
	local to = Vector3.new(Config.Lane.StartX + distance, GROUND_Y, math.clamp(root.Position.Z, -laneHalf, laneHalf))

	inFlight[player] = true
	local egg = makeEgg(from, stage.Color)
	Remotes.EggLaunched:FireClient(player, egg, stage.Name)

	flyEgg(egg, from, to, function()
		if player.Parent ~= Players then
			(egg.Parent or egg):Destroy()
			inFlight[player] = nil
			return
		end
		Remotes.EggLanded:FireClient(player, zoneIndex, stage.Name, distance)

		-- The server decides the pet now; the client plays the crack and reveal
		-- while the egg sits on the lane.
		local pet, merged, kept, isNew = HatchService.hatch(player, distance)
		local notable = pet ~= nil and Pets.isNotable(pet)
		if pet then
			Remotes.EggHatched:FireClient(player, egg, pet, merged, kept, isNew)
			if notable then
				Remotes.BigHatch:FireAllClients(player.DisplayName, to, pet)
			end
			if not kept then
				EconomyService.notify(player, "Your pets are full! Only pets better than your weakest are kept.", "error")
			end
			EconomyService.publish(player)
		end

		local revealTime = if notable then Config.Hatching.BigRevealSeconds else Config.Hatching.RevealSeconds
		task.delay(revealTime, function()
			local holder = egg.Parent or egg
			holder:Destroy()
			inFlight[player] = nil
			if pet and player.Parent then
				PlotService.refresh(player)
			end
		end)
	end)
end

function LaunchService.init()
	Remotes.ChargeStart.OnServerEvent:Connect(onChargeStart)
	Remotes.ChargeRelease.OnServerEvent:Connect(onChargeRelease)
	Players.PlayerRemoving:Connect(function(player)
		chargeStarted[player] = nil
		inFlight[player] = nil
	end)
end

return LaunchService
