--!strict
-- The game's look: sunny afternoon light, soft shadows, a light haze for depth,
-- puffy clouds, a gentle glow on bright things and a little extra colour.
-- Aims for the bright, saturated feel of top Roblox simulators.
-- Everything here is in Lighting (and workspace.Terrain for clouds), which
-- replicates to every client. Tune the numbers in LOOK while playtesting.
--
-- One setting can't be changed from a script: in Studio, select Lighting and set
-- Technology to Future (best) or ShadowMap. Voxel looks flat and blocky.

local Lighting = game:GetService("Lighting")

local Environment = {}

local LOOK = {
	ClockTime = 14.5, -- early afternoon: sun high but not straight down, so shadows show shape
	Latitude = 35,
	Brightness = 3,
	Exposure = 0.1,
	Ambient = Color3.fromRGB(120, 120, 135), -- shade colour indoors / under things
	OutdoorAmbient = Color3.fromRGB(150, 150, 170), -- keeps shadows light and friendly, never black
	SunTint = Color3.fromRGB(255, 244, 222), -- warm sunlight
	ShadowSoftness = 0.3,

	-- Haze. Kept light: the lane is 2,000 studs long and the far zones should still show.
	AtmosphereDensity = 0.24,
	AtmosphereOffset = 0.1,
	AtmosphereColor = Color3.fromRGB(205, 225, 255),
	AtmosphereDecay = Color3.fromRGB(120, 160, 220),
	AtmosphereGlare = 0.35,
	AtmosphereHaze = 0.9,

	CloudCover = 0.55,
	CloudDensity = 0.6,

	BloomIntensity = 0.55,
	BloomSize = 28,
	BloomThreshold = 1.5, -- only neon and very bright things glow, not the grass

	Saturation = 0.18,
	Contrast = 0.07,
	BrightnessBoost = 0.02,
	Tint = Color3.fromRGB(255, 252, 246),

	SunRays = 0.07,
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
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = LOOK.ShadowSoftness
	Lighting.FogEnd = 100000 -- the Atmosphere does the haze

	-- Default Roblox sky textures (blue with soft clouds), with a big friendly sun.
	make("Sky", {
		SunAngularSize = 16,
		MoonAngularSize = 11,
		StarCount = 3000,
		CelestialBodiesShown = true,
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

	-- Real 3D clouds drifting across the sky.
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = LOOK.CloudCover
	clouds.Density = LOOK.CloudDensity
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = terrain
end

return Environment
