--!strict
-- The hatch: after your egg lands it shakes (tap to hurry it), cracks, and the
-- pet pops out and hops toward the camera, then a reveal card shows what you got.
-- Pets rare enough for a light beam get a longer build first: the egg glows,
-- floats and spins. Everyone in the server sees the beam and a banner for those.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Format = require(Shared.Format)
local PetModel = require(Shared.PetModel)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FONT = Enum.Font.FredokaOne
local SHAKE_SECONDS = 1.3 -- normal hatch: shakes before the crack
local CARD_SECONDS = 3.2 -- how long the reveal card stays unless tapped away
local SHELL_COLOR = Color3.fromRGB(255, 250, 235)

local gui = Instance.new("ScreenGui")
gui.Name = "HatchGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
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

--------------------------------------------------------------------------------
-- Tap to hurry
--------------------------------------------------------------------------------

local tapped = false

local tapHint = label({
	Name = "TapHint",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(260, 60),
	Text = "Tap!",
	Visible = false,
	Parent = gui,
})

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.E
	then
		tapped = true
	end
end)

--------------------------------------------------------------------------------
-- Reveal card
--------------------------------------------------------------------------------

local card = Instance.new("TextButton")
card.Name = "RevealCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.42)
card.Size = UDim2.fromOffset(380, 170)
card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
card.BackgroundTransparency = 0.1
card.AutoButtonColor = false
card.Text = ""
card.Visible = false
card.Parent = gui
corner(card, UDim.new(0, 24))
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 5
cardStroke.Parent = card
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local viewport = Instance.new("ViewportFrame")
viewport.Position = UDim2.fromOffset(10, 10)
viewport.Size = UDim2.fromOffset(150, 150)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(200, 200, 200)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -1, -0.5)
viewport.Parent = card
local viewportCamera = Instance.new("Camera")
viewportCamera.FieldOfView = 40
viewportCamera.Parent = viewport
viewport.CurrentCamera = viewportCamera

local nameLabel = label({ Position = UDim2.fromOffset(170, 14), Size = UDim2.new(1, -184, 0, 44), Parent = card })
local rarityLabel = label({ Position = UDim2.fromOffset(170, 62), Size = UDim2.new(1, -184, 0, 30), Parent = card })
local rateLabel = label({
	Position = UDim2.fromOffset(170, 96),
	Size = UDim2.new(1, -184, 0, 30),
	TextColor3 = Color3.fromRGB(255, 225, 90),
	Parent = card,
})
local noteLabel = label({ Position = UDim2.fromOffset(170, 130), Size = UDim2.new(1, -184, 0, 24), Parent = card })

local cardPet: Model? = nil
local cardShownAt = 0

local function hideCard()
	if not card.Visible then
		return
	end
	local shownAt = cardShownAt
	local tween = TweenService:Create(cardScale, TweenInfo.new(0.15), { Scale = 0 })
	tween:Play()
	tween.Completed:Wait()
	if cardShownAt ~= shownAt then
		return -- a new card came up meanwhile
	end
	card.Visible = false
	if cardPet then
		cardPet:Destroy()
		cardPet = nil
	end
end

card.Activated:Connect(function()
	task.spawn(hideCard)
end)

local function showCard(pet: Pets.Pet, merged: boolean, kept: boolean)
	local def = Pets.ById[pet.Id]
	local rarity = Config.Rarities[if def then def.Rarity else 1]
	local mutation = if pet.Mutation then Config.Mutations[pet.Mutation] else nil
	local color = Pets.color(pet)

	if cardPet then
		cardPet:Destroy()
	end
	local model = PetModel.build(pet, CFrame.new())
	model.Parent = viewport
	cardPet = model
	local scale = if pet.Big then 1.6 else 1
	viewportCamera.CFrame = CFrame.lookAt(Vector3.new(8, 3.5, 3.5) * scale, Vector3.new(0, 1.7, 0) * scale)

	nameLabel.Text = Pets.displayName(pet)
	nameLabel.TextColor3 = color
	rarityLabel.Text = if mutation then `{rarity.Name} · {mutation.Name} x{mutation.Multiplier}` else rarity.Name
	rarityLabel.TextColor3 = rarity.Color
	rateLabel.Text = `+{Format.number(Pets.earnRate(pet))} coins/s`
	noteLabel.Text = if not kept then "Pets full: not kept" elseif merged then "3 combined into a BIG pet!" else ""
	cardStroke.Color = color

	card.Visible = true
	cardScale.Scale = 0.3
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local shownAt = os.clock()
	cardShownAt = shownAt
	task.delay(CARD_SECONDS, function()
		if cardShownAt == shownAt then
			hideCard()
		end
	end)
end

-- Slowly turn the pet in the card from side to side.
RunService.RenderStepped:Connect(function()
	if cardPet and card.Visible then
		local t = os.clock() - cardShownAt
		cardPet:PivotTo(CFrame.new(0, cardPet:GetPivot().Y, 0) * CFrame.Angles(0, math.sin(t * 2) * 0.6, 0))
	end
end)

--------------------------------------------------------------------------------
-- Effects in the world (all local to this client)
--------------------------------------------------------------------------------

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = workspace
	return p
end

-- A puff of dust where the egg lands.
local function dustPuff(position: Vector3)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local puff = localPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			Color = Color3.fromRGB(235, 230, 215),
			Transparency = 0.3,
			Position = position + Vector3.new(0, -1, 0),
		})
		local goal = position + Vector3.new(math.cos(angle) * 5, 0.5, math.sin(angle) * 5)
		TweenService:Create(puff, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = goal,
			Size = Vector3.one * 3.5,
			Transparency = 1,
		}):Play()
		task.delay(0.7, function()
			puff:Destroy()
		end)
	end
end

-- Shell pieces fly out when the egg cracks.
local function shellBurst(position: Vector3)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local shard = localPart({
			Size = Vector3.new(1.2, 0.3, 1),
			Color = SHELL_COLOR,
			CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 3, angle, math.random() * 3),
		})
		local goal = CFrame.new(position + Vector3.new(math.cos(angle) * 5, 2 + math.random() * 2, math.sin(angle) * 5))
			* CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		TweenService:Create(shard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = goal,
			Transparency = 1,
		}):Play()
		task.delay(0.8, function()
			shard:Destroy()
		end)
	end
end

-- A tall beam of light in the pet's colour, seen from anywhere on the map.
local function lightBeam(position: Vector3, color: Color3)
	local height = 400
	local beam = localPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2, 2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	TweenService:Create(beam, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(height, 7, 7),
	}):Play()
	task.delay(3, function()
		local fade = TweenService:Create(beam, TweenInfo.new(1.2), { Transparency = 1, Size = Vector3.new(height, 1, 1) })
		fade:Play()
		fade.Completed:Wait()
		beam:Destroy()
	end)
end

-- Confetti falling over the screen.
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(110, 210, 110),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(170, 90, 255),
}
local function confetti()
	for _ = 1, 45 do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.Size = UDim2.fromOffset(10, 16)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.Position = UDim2.new(math.random(), 0, 0, -20)
		piece.Rotation = math.random(0, 360)
		piece.Parent = gui
		local fall = 1.6 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(fall, function()
			piece:Destroy()
		end)
	end
end

--------------------------------------------------------------------------------
-- Your hatch
--------------------------------------------------------------------------------

-- Plays the hatch on your landed egg, then shows the card.
local function playHatch(egg: BasePart?, pet: Pets.Pet, merged: boolean, kept: boolean)
	if not (egg and egg:IsDescendantOf(workspace)) then
		showCard(pet, merged, kept)
		return
	end
	local base = egg.CFrame
	local ground = base.Position - Vector3.new(0, 2, 0)
	local notable = Pets.isNotable(pet)
	local color = Pets.color(pet)
	dustPuff(ground)

	-- Build-up: shakes for a normal pet; glow, float and spin for a rare one.
	tapped = false
	tapHint.Visible = true
	local glow: PointLight? = nil
	if notable then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 0
		light.Brightness = 3
		light.Parent = egg
		TweenService:Create(light, TweenInfo.new(Config.Hatching.BuildSeconds), { Range = 18 }):Play()
		glow = light
	end
	local duration = if notable then Config.Hatching.BuildSeconds else SHAKE_SECONDS
	local start = os.clock()
	while os.clock() - start < duration and not tapped and egg:IsDescendantOf(workspace) do
		local t = os.clock() - start
		if notable then
			local rise = math.min(t / duration, 1)
			egg.CFrame = base * CFrame.new(0, rise * 5, 0) * CFrame.Angles(0, t * t * 4, 0)
		else
			-- Three quick wobbles with pauses between them.
			local phase = t % (SHAKE_SECONDS / 3)
			local wobble = if phase < 0.25 then math.sin(phase / 0.25 * math.pi * 3) * 0.35 else 0
			egg.CFrame = base * CFrame.Angles(wobble, 0, wobble * 0.5)
		end
		RunService.RenderStepped:Wait()
	end
	tapHint.Visible = false
	if glow then
		glow:Destroy()
	end
	if not egg:IsDescendantOf(workspace) then
		showCard(pet, merged, kept)
		return
	end

	-- Crack: hide the egg, burst the shell, pop the pet out facing the camera.
	local crackAt = egg.Position
	egg.LocalTransparencyModifier = 1
	shellBurst(crackAt)
	local flatCamera = Vector3.new(camera.CFrame.Position.X, ground.Y, camera.CFrame.Position.Z)
	local facing = CFrame.lookAt(ground, flatCamera) * CFrame.Angles(0, math.pi / 2, 0)
	local popped = PetModel.build(pet, facing)
	popped.Parent = workspace
	local grow = Instance.new("NumberValue")
	grow.Value = 0.2
	popped:ScaleTo(grow.Value)
	grow.Changed:Connect(function(value)
		if popped.Parent and value > 0 then
			popped:ScaleTo(value)
		end
	end)
	TweenService:Create(grow, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
	if notable then
		confetti()
	end
	showCard(pet, merged, kept)

	-- A happy little hop, then the pet stays until the egg is cleared away.
	local hopStart = os.clock()
	local pivot = popped:GetPivot()
	while egg:IsDescendantOf(workspace) and popped.Parent do
		local t = os.clock() - hopStart
		local hop = math.abs(math.sin(t * 5)) * 1.2 * math.max(0, 1 - t / 2)
		popped:PivotTo(pivot + Vector3.new(0, hop, 0))
		RunService.RenderStepped:Wait()
	end
	popped:Destroy()
	grow:Destroy()
end

Remotes.EggHatched.OnClientEvent:Connect(function(egg: BasePart?, pet: Pets.Pet, merged: boolean, kept: boolean)
	task.spawn(playHatch, egg, pet, merged, kept)
end)

--------------------------------------------------------------------------------
-- Rare hatches, for everyone
--------------------------------------------------------------------------------

local banner = label({
	Name = "BigHatchBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 140),
	Size = UDim2.fromOffset(640, 54),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

Remotes.BigHatch.OnClientEvent:Connect(function(playerName: string, position: Vector3, pet: Pets.Pet)
	-- Wait for the build-up, so the beam shoots up when the egg cracks.
	task.wait(Config.Hatching.BuildSeconds)
	local def = Pets.ById[pet.Id]
	local rarity = Config.Rarities[if def then def.Rarity else 1]
	local color = Pets.color(pet)
	lightBeam(position, color)

	local text = `{playerName} hatched a {rarity.Name} {Pets.displayName(pet)}!`
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.1
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(4, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)
