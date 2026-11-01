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

	-- Purple haze that tints the sky and the far end of the lane.
	AtmosphereDensity = 0.3,
	AtmosphereOffset = 0.15,
	AtmosphereColor = Color3.fromRGB(175, 120, 210),
	AtmosphereDecay = Color3.fromRGB(110, 60, 150),
	AtmosphereGlare = 0,
	AtmosphereHaze = 1.6,

	CloudCover = 0.45,
	CloudDensity = 0.45,
	CloudColor = Color3.fromRGB(215, 175, 230), -- lavender clouds

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

	-- Default sky textures; the dusk time and the purple Atmosphere colour them.
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
	clouds.Color = LOOK.CloudColor
	clouds.Parent = terrain
end

return Environment
