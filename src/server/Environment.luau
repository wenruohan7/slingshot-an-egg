--!strict
-- The game's look, matched to Tmuk's reference screenshots: a purple dusk sky
-- with a warm orange glow low down, soft light, flat matte colours (no shine or
-- glare) and strong, saturated greens. Nothing glossy: no specular highlights,
-- almost no bloom, no sun rays.
-- Everything here is in Lighting (and workspace.Terrain for clouds), which
-- replicates to every client. Tune the numbers in LOOK while playtesting.
--
-- One setting can't be changed from a script: in Studio, select Lighting and set
-- Technology to Future (best) or ShadowMap. Voxel looks flat and blocky.

local Lighting = game:GetService("Lighting")

local Environment = {}

local LOOK = {
	ClockTime = 17.4, -- late afternoon going on dusk: warm low sun, purple sky
	Latitude = 25,
	Brightness = 2,
	Exposure = 0,
	Ambient = Color3.fromRGB(110, 95, 140), -- purple-ish shade
	OutdoorAmbient = Color3.fromRGB(150, 130, 175),
	SunTint = Color3.fromRGB(255, 205, 165), -- warm orange sunlight
	ShadowSoftness = 0.5,
	DiffuseScale = 0.35, -- how much the sky lights things; low keeps colours flat
	SpecularScale = 0, -- no shiny reflections on anything

	-- The sky (Tmuk's screenshot): deep violet overhead fading to magenta at the
	-- horizon, no clouds. A thick Atmosphere paints the default sky in these colours;
	-- Offset keeps the hub and near zones clear while the horizon goes purple.
	AtmosphereDensity = 0.36,
	AtmosphereOffset = 0.4,
	AtmosphereColor = Color3.fromRGB(200, 90, 190), -- magenta near the horizon
	AtmosphereDecay = Color3.fromRGB(75, 30, 120), -- deep violet higher up
	AtmosphereGlare = 0,
	AtmosphereHaze = 2.4,

	-- The big orange dusk sun, low on the right as you look down the lane, with
	-- dark streaks of cloud across it. Drawn as a flat disc far away (the real
	-- sun is hidden), so it looks the same on every device.
	SunPosition = Vector3.new(3200, 1000, 1300), -- +X is down the lane, +Z is to its right
	SunSize = 520, -- studs across
	SunColor = Color3.fromRGB(255, 150, 60),
	SunEdgeColor = Color3.fromRGB(235, 95, 45),
	SunGlowColor = Color3.fromRGB(255, 120, 90),
	StreakColor = Color3.fromRGB(95, 35, 95),

	BloomIntensity = 0.15,
	BloomSize = 18,
	BloomThreshold = 2.6, -- only neon glows a little

	Saturation = 0.22,
	Contrast = 0.12,
	BrightnessBoost = -0.02,
	Tint = Color3.fromRGB(250, 240, 255), -- a touch of purple over everything

	SunRays = 0,
}

local function make(className: string, props: { [string]: any }): Instance
	local item = Instance.new(className)
	for key, value in props do
		(item :: any)[key] = value
	end
	item.Parent = Lighting
	return item
end

function Environment.apply()
	-- Replace whatever the place template put in Lighting, so the look is the same
	-- in every place file.
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	-- Not scriptable in live games; this only works where Roblox allows it.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)

	Lighting.ClockTime = LOOK.ClockTime
	Lighting.GeographicLatitude = LOOK.Latitude
	Lighting.Brightness = LOOK.Brightness
	Lighting.ExposureCompensation = LOOK.Exposure
	Lighting.Ambient = LOOK.Ambient
	Lighting.OutdoorAmbient = LOOK.OutdoorAmbient
	Lighting.ColorShift_Top = LOOK.SunTint
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = LOOK.DiffuseScale
	Lighting.EnvironmentSpecularScale = LOOK.SpecularScale
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = LOOK.ShadowSoftness
	Lighting.FogEnd = 100000 -- the Atmosphere does the haze

	-- Default sky textures, coloured by the Atmosphere. No real sun, moon or stars:
	-- our own sun is drawn below.
	make("Sky", {
		StarCount = 0,
		CelestialBodiesShown = false,
	})

	make("Atmosphere", {
		Density = LOOK.AtmosphereDensity,
		Offset = LOOK.AtmosphereOffset,
		Color = LOOK.AtmosphereColor,
		Decay = LOOK.AtmosphereDecay,
		Glare = LOOK.AtmosphereGlare,
		Haze = LOOK.AtmosphereHaze,
	})

	make("BloomEffect", {
		Intensity = LOOK.BloomIntensity,
		Size = LOOK.BloomSize,
		Threshold = LOOK.BloomThreshold,
	})

	make("ColorCorrectionEffect", {
		Saturation = LOOK.Saturation,
		Contrast = LOOK.Contrast,
		Brightness = LOOK.BrightnessBoost,
		TintColor = LOOK.Tint,
	})

	make("SunRaysEffect", {
		Intensity = LOOK.SunRays,
		Spread = 0.8,
	})

	-- No 3D clouds: the reference sky is clear apart from the streaks on the sun.
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end

	Environment.buildSun()
end

local function disc(parent: Instance, name: string, size: number, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(size, size)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = frame
	return frame
end

-- The dusk sun: a soft glow, an orange disc that darkens toward its lower edge,
-- and three dark streaks of cloud across its lower half.
function Environment.buildSun()
	local old = workspace:FindFirstChild("SkySun")
	if old then
		old:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SkySun"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = LOOK.SunPosition

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sun"
	billboard.Size = UDim2.fromScale(LOOK.SunSize * 1.8, LOOK.SunSize * 1.8) -- room for the glow
	billboard.LightInfluence = 0
	billboard.MaxDistance = math.huge
	billboard.Parent = anchor

	disc(billboard, "OuterGlow", 1, LOOK.SunGlowColor, 0.88)
	disc(billboard, "Glow", 0.78, LOOK.SunGlowColor, 0.75)
	local sun = disc(billboard, "Disc", 1 / 1.8, Color3.new(1, 1, 1), 0)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(LOOK.SunColor, LOOK.SunEdgeColor)
	shade.Rotation = 90
	shade.Parent = sun

	-- Streaks: (centre X, centre Y, width) as fractions of the billboard.
	for i, streak in { { 0.45, 0.56, 0.42 }, { 0.58, 0.62, 0.38 }, { 0.48, 0.68, 0.3 } } do
		local bar = Instance.new("Frame")
		bar.Name = "Streak" .. i
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(streak[1], streak[2])
		bar.Size = UDim2.fromScale(streak[3], 0.035)
		bar.BackgroundColor3 = LOOK.StreakColor
		bar.BackgroundTransparency = 0.25
		bar.BorderSizePixel = 0
		bar.Parent = billboard
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = bar
	end

	-- It's far beyond streaming range, so keep it sent to every player.
	local holder = Instance.new("Model")
	holder.Name = "SkySun"
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	anchor.Parent = holder
	holder.Parent = workspace
end

return Environment
