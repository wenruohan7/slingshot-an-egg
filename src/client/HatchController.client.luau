--!strict
-- The hatch: after your egg lands it shakes (tap to hurry it), cracks, and the
-- pet pops out as a dark silhouette. Then the reveal: a "1 in N" number climbs
-- to the real odds of what you hatched, luck banners pop as it passes 100,
-- 10,000 and 1,000,000, and the pet's name fills in letter by letter. At the
-- end the pet lights up in its colours with a flash and sparkles, and its name,
-- rarity and coins per second show under it, with NEW! the first time.
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
local DARK = Color3.fromRGB(25, 20, 35)
local SHAKE_SECONDS = 1.3 -- normal hatch: shakes before the crack
local SHOW_SECONDS = 3.2 -- how long the name stays after the reveal unless tapped away
local SHOW_ODDS_FROM = 2 -- "1 in 1" isn't exciting, so very common pets skip the number
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

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

-- Thick dark outline around text, like the big numbers in simulator games.
local function outline(target: GuiObject, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = target
	return stroke
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 1
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function popIn(target: GuiObject, from: number?)
	local scale: UIScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = target
	scale.Scale = from or 0.3
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Taps: hurry the shake, skip the climbing number, close the reveal
--------------------------------------------------------------------------------

local tapped = false
local onTap: (() -> ())? = nil

local tapHint = label({
	Name = "TapHint",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(260, 60),
	Text = "Tap!",
	Visible = false,
	Parent = gui,
})
outline(tapHint, 3)

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
		if onTap then
			onTap()
		end
	end
end)

--------------------------------------------------------------------------------
-- Reveal overlay: odds along the top, the name along the bottom
--------------------------------------------------------------------------------

local overlay = Instance.new("Frame")
overlay.Name = "Reveal"
overlay.BackgroundTransparency = 1
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.Parent = gui

-- Fit the whole overlay to small phone screens.
local overlayScale = Instance.new("UIScale")
overlayScale.Parent = overlay
local function fitOverlay()
	local screen = gui.AbsoluteSize
	if screen.Y > 0 then
		overlayScale.Scale = math.clamp(screen.Y / 720, 0.6, 1.2)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitOverlay)
fitOverlay()

-- A soft dark band behind the odds, so the number reads on bright grass.
local oddsBand = Instance.new("Frame")
oddsBand.AnchorPoint = Vector2.new(0.5, 0)
oddsBand.Position = UDim2.new(0.5, 0, 0, 70)
oddsBand.Size = UDim2.fromOffset(520, 96)
oddsBand.BackgroundColor3 = Color3.new(0, 0, 0)
oddsBand.BackgroundTransparency = 0.65
oddsBand.Parent = overlay
corner(oddsBand, UDim.new(1, 0))
local bandFade = Instance.new("UIGradient")
bandFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0),
	NumberSequenceKeypoint.new(0.75, 0),
	NumberSequenceKeypoint.new(1, 1),
})
bandFade.Parent = oddsBand

local luckBanner = label({
	Name = "LuckBanner",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.fromOffset(420, 40),
	Rotation = -3,
	Text = "",
	Parent = overlay,
})
outline(luckBanner, 3)

local oddsLabel = label({
	Name = "Odds",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(500, 70),
	Text = "",
	Parent = overlay,
})
outline(oddsLabel, 5)

local nameLabel = label({
	Name = "PetName",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -128),
	Size = UDim2.fromOffset(620, 64),
	Text = "",
	Parent = overlay,
})
outline(nameLabel, 5)

local rarityLabel = label({
	Name = "Rarity",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -94),
	Size = UDim2.fromOffset(500, 34),
	Text = "",
	Parent = overlay,
})
outline(rarityLabel, 3)

local rateLabel = label({
	Name = "Rate",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -60),
	Size = UDim2.fromOffset(400, 34),
	TextColor3 = Color3.fromRGB(255, 225, 90),
	Text = "",
	Parent = overlay,
})
outline(rateLabel, 3)

local noteLabel = label({
	Name = "Note",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.fromOffset(400, 24),
	TextColor3 = Color3.fromRGB(255, 150, 150),
	Text = "",
	Parent = overlay,
})
outline(noteLabel, 2)

local continueLabel = label({
	Name = "TapToContinue",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(220, 22),
	TextColor3 = Color3.fromRGB(230, 230, 240),
	Text = "tap to continue",
	Parent = overlay,
})
outline(continueLabel, 2)

-- "NEW!" sticker next to the name the first time you hatch a pet.
local newTag = label({
	Name = "New",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 250, 1, -175),
	Size = UDim2.fromOffset(110, 44),
	Rotation = -12,
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(255, 200, 40),
	Text = "NEW!",
	Parent = overlay,
})
corner(newTag, UDim.new(0, 10))
outline(newTag, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local newText = Instance.new("UIStroke")
newText.Color = DARK
newText.Thickness = 2.5
newText.Parent = newTag
local newPadding = Instance.new("UIPadding")
newPadding.PaddingTop = UDim.new(0, 5)
newPadding.PaddingBottom = UDim.new(0, 5)
newPadding.Parent = newTag

-- Used only if the egg is gone before the reveal (no pet in the world to look at).
local viewport = Instance.new("ViewportFrame")
viewport.AnchorPoint = Vector2.new(0.5, 0.5)
viewport.Position = UDim2.fromScale(0.5, 0.48)
viewport.Size = UDim2.fromOffset(260, 260)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(200, 200, 200)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -1, -0.5)
viewport.Visible = false
viewport.Parent = overlay
local viewportCamera = Instance.new("Camera")
viewportCamera.FieldOfView = 40
viewportCamera.Parent = viewport
viewport.CurrentCamera = viewportCamera
local viewportPet: Model? = nil

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 10
flash.Parent = gui

local function doFlash(strength: number)
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

-- Each reveal gets a number, so an old one never hides a newer one.
local revealId = 0

local function hideOverlay(id: number)
	if revealId ~= id or not overlay.Visible then
		return
	end
	onTap = nil
	local fade = TweenService:Create(overlayScale, TweenInfo.new(0.15), { Scale = 0 })
	fade:Play()
	fade.Completed:Wait()
	if revealId ~= id then
		return
	end
	overlay.Visible = false
	fitOverlay()
	if viewportPet then
		viewportPet:Destroy()
		viewportPet = nil
	end
end

-- "Bubble Crab" with `shown` letters showing, in a random order: "_u__le C_a_".
local function partialName(name: string, order: { number }, shown: number): string
	local visible = {}
	for i = 1, math.min(shown, #order) do
		visible[order[i]] = true
	end
	local out = table.create(#name)
	local index = 0
	for _, code in utf8.codes(name) do
		index += 1
		local char = utf8.char(code)
		out[index] = if char == " " or visible[index] then char else "_"
	end
	return table.concat(out)
end

local function letterOrder(name: string): { number }
	local order = {}
	local index = 0
	for _, code in utf8.codes(name) do
		index += 1
		if utf8.char(code) ~= " " then
			table.insert(order, index)
		end
	end
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local function bannerFor(odds: number): { From: number, Text: string, Color: Color3 }?
	local best = nil
	for _, banner in Config.Hatching.LuckBanners do
		if odds >= banner.From then
			best = banner
		end
	end
	return best
end

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
local function shellBurst(position: Vector3, color: Color3)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local shard = localPart({
			Size = Vector3.new(1.2, 0.3, 1),
			Color = color,
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

-- A burst of sparkles in the pet's colour, out of the pet itself.
local function sparkleBurst(model: Model, color: Color3, count: number)
	local target = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not target then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLES
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = target
	emitter:Emit(count)
	task.delay(1.5, function()
		emitter:Destroy()
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
local function confetti(count: number)
	for _ = 1, count do
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
-- The reveal
--------------------------------------------------------------------------------

type Hatch = {
	pet: Pets.Pet,
	merged: boolean,
	kept: boolean,
	isNew: boolean,
	odds: number,
}

-- Seconds the number climbs for: longer for rarer pets.
local function rollSeconds(odds: number): number
	if odds < SHOW_ODDS_FROM then
		return 0
	end
	return math.min(Config.Hatching.MaxRollSeconds, Config.Hatching.RollSecondsPerDigit * math.log10(odds))
end

-- Climbs the number and fills in the name, then shows everything about the pet.
-- `world` is the popped pet on the lane (shown as a silhouette until the end),
-- or nil to show the pet in a picture instead.
local function reveal(hatch: Hatch, world: Model?, silhouette: Highlight?)
	revealId += 1
	local id = revealId
	local pet = hatch.pet
	local def = Pets.ById[pet.Id]
	local rarity = Config.Rarities[if def then def.Rarity else 1]
	local mutation = if pet.Mutation then Config.Mutations[pet.Mutation] else nil
	local color = Pets.color(pet)
	local name = Pets.displayName(pet)
	local notable = Pets.isNotable(pet)
	local showOdds = hatch.odds >= SHOW_ODDS_FROM

	-- Start: dark name, no details yet.
	overlay.Visible = true
	fitOverlay()
	luckBanner.Text = ""
	oddsLabel.Text = if showOdds then "1 in 1" else ""
	oddsBand.Visible = showOdds
	nameLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	rarityLabel.Text = ""
	rateLabel.Text = ""
	noteLabel.Text = ""
	continueLabel.Visible = false
	newTag.Visible = false

	if not world then
		if viewportPet then
			viewportPet:Destroy()
		end
		local model = PetModel.build(pet, CFrame.new())
		model.Parent = viewport
		viewportPet = model
		local scale = if pet.Big then 1.6 else 1
		viewportCamera.CFrame = CFrame.lookAt(Vector3.new(8, 3.5, 3.5) * scale, Vector3.new(0, 1.7, 0) * scale)
		viewport.Visible = true
		viewport.ImageColor3 = Color3.new(0, 0, 0) -- silhouette
	else
		viewport.Visible = false
	end

	-- Climb.
	local seconds = rollSeconds(hatch.odds)
	local order = letterOrder(name)
	local skip = false
	onTap = function()
		skip = true
	end
	local banner: { From: number, Text: string, Color: Color3 }? = nil
	local start = os.clock()
	while revealId == id do
		local t = if seconds > 0 then math.clamp((os.clock() - start) / seconds, 0, 1) else 1
		if skip then
			t = 1
		end
		-- The number climbs evenly through the digits: 1, 10, 100, 1,000...
		local shown = if t >= 1 then hatch.odds else hatch.odds ^ t
		if showOdds then
			oddsLabel.Text = `1 in {Format.commas(math.max(1, shown))}`
		end
		local reached = bannerFor(shown)
		if reached and reached ~= banner then
			banner = reached
			luckBanner.Text = reached.Text
			luckBanner.TextColor3 = reached.Color
			popIn(luckBanner, 1.8)
			popIn(oddsLabel, 1.25)
		end
		nameLabel.Text = partialName(name, order, math.floor(t * #order))
		if world and world.Parent then
			-- The silhouette slowly turns while you wait.
			local pivot = world:GetPivot()
			world:PivotTo(pivot * CFrame.Angles(0, 0.02 + t * 0.06, 0))
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if revealId ~= id then
		return
	end

	-- Reveal!
	doFlash(if notable then 0.85 else 0.5)
	nameLabel.Text = name
	nameLabel.TextColor3 = color
	popIn(nameLabel, 1.6)
	if showOdds then
		oddsLabel.Text = `1 in {Format.commas(hatch.odds)}`
		popIn(oddsLabel, 1.3)
	end
	rarityLabel.Text = if mutation then `{rarity.Name} · {mutation.Name} x{mutation.Multiplier}` else rarity.Name
	rarityLabel.TextColor3 = rarity.Color
	popIn(rarityLabel)
	rateLabel.Text = `+{Format.number(Pets.earnRate(pet))} coins/s`
	popIn(rateLabel)
	noteLabel.Text = if not hatch.kept then "Pets full: not kept" elseif hatch.merged then "3 combined into a BIG pet!" else ""
	newTag.Visible = hatch.isNew
	if hatch.isNew then
		popIn(newTag, 2)
	end
	viewport.ImageColor3 = Color3.new(1, 1, 1)
	if silhouette then
		TweenService:Create(silhouette, TweenInfo.new(0.35), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		task.delay(0.4, function()
			silhouette:Destroy()
		end)
	end
	if world and world.Parent then
		sparkleBurst(world, color, if notable then 80 else 30)
		if notable then
			lightBeam(world:GetPivot().Position, color)
		end
	end
	if notable or hatch.odds >= Config.Hatching.LuckBanners[1].From then
		confetti(if notable then 60 else 30)
	end

	-- Stay up until tapped (after a moment, so the skip tap doesn't close it) or timed out.
	task.delay(0.4, function()
		if revealId == id then
			continueLabel.Visible = true
			onTap = function()
				task.spawn(hideOverlay, id)
			end
		end
	end)
	task.delay(SHOW_SECONDS + seconds * 0.25, function()
		hideOverlay(id)
	end)
end

--------------------------------------------------------------------------------
-- Your hatch
--------------------------------------------------------------------------------

-- Plays the hatch on your landed egg, then the reveal.
local function playHatch(egg: BasePart?, hatch: Hatch)
	local pet = hatch.pet
	if not (egg and egg:IsDescendantOf(workspace)) then
		reveal(hatch, nil, nil)
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
		reveal(hatch, nil, nil)
		return
	end

	-- Crack: hide the egg, burst the shell, pop the pet out facing the camera,
	-- dark until the reveal.
	local crackAt = egg.Position
	egg.LocalTransparencyModifier = 1
	shellBurst(crackAt, egg.Color)
	local flatCamera = Vector3.new(camera.CFrame.Position.X, ground.Y, camera.CFrame.Position.Z)
	local facing = CFrame.lookAt(ground, flatCamera) * CFrame.Angles(0, math.pi / 2, 0)
	local popped = PetModel.build(pet, facing)
	popped.Parent = workspace
	local silhouette = Instance.new("Highlight")
	silhouette.FillColor = Color3.new(0, 0, 0)
	silhouette.FillTransparency = 0
	silhouette.OutlineColor = Color3.new(1, 1, 1)
	silhouette.OutlineTransparency = 0.3
	silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
	silhouette.Adornee = popped
	silhouette.Parent = popped
	local fullScale = popped:GetScale() -- real pet models are already resized
	local grow = Instance.new("NumberValue")
	grow.Value = 0.2
	popped:ScaleTo(fullScale * grow.Value)
	grow.Changed:Connect(function(value)
		if popped.Parent and value > 0 then
			popped:ScaleTo(fullScale * value)
		end
	end)
	TweenService:Create(grow, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()

	-- Keep the pet until the egg is cleared away; the reveal runs meanwhile.
	task.spawn(function()
		while egg:IsDescendantOf(workspace) and popped.Parent do
			RunService.RenderStepped:Wait()
		end
		popped:Destroy()
		grow:Destroy()
	end)
	reveal(hatch, popped, silhouette)

	-- A happy little hop and a size punch once it's revealed.
	if popped.Parent then
		grow.Value = 1.25
		TweenService:Create(grow, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
			:Play()
	end
	local hopStart = os.clock()
	local pivot = if popped.Parent then popped:GetPivot() else CFrame.new()
	while popped.Parent and os.clock() - hopStart < 2 do
		local t = os.clock() - hopStart
		local hop = math.abs(math.sin(t * 5)) * 1.2 * math.max(0, 1 - t / 2)
		popped:PivotTo(pivot + Vector3.new(0, hop, 0))
		RunService.RenderStepped:Wait()
	end
end

Remotes.EggHatched.OnClientEvent:Connect(
	function(egg: BasePart?, pet: Pets.Pet, merged: boolean, kept: boolean, isNew: boolean?, odds: number?)
		task.spawn(playHatch, egg, {
			pet = pet,
			merged = merged,
			kept = kept,
			isNew = isNew == true,
			odds = if typeof(odds) == "number" and odds >= 1 then odds else 1,
		})
	end
)

--------------------------------------------------------------------------------
-- Rare hatches, for everyone else
--------------------------------------------------------------------------------

local banner = label({
	Name = "BigHatchBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 200),
	Size = UDim2.fromOffset(640, 54),
	TextTransparency = 1,
	Parent = gui,
})
local bannerStroke = outline(banner, 3)
bannerStroke.Transparency = 1
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

Remotes.BigHatch.OnClientEvent:Connect(function(playerName: string, position: Vector3, pet: Pets.Pet, userId: number?)
	if userId == player.UserId then
		return -- your own reveal plays the beam
	end
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
	bannerStroke.Transparency = 0
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(4, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end)
