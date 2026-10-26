--!strict
-- The big menu buttons on the left (Shop and Index, with red badges), the hint
-- line along the top of the screen, and the two panels they open:
-- the Index (every pet, found or not) and the Shop (your upgrades and where to buy them).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Pets = require(Shared.Pets)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(40, 40, 60)
local BADGE_COLOR = Color3.fromRGB(235, 50, 50)
local GOOD_COLOR = Color3.fromRGB(120, 230, 120)
local BAD_COLOR = Color3.fromRGB(255, 120, 120)
local UNKNOWN_COLOR = Color3.fromRGB(70, 70, 90)

-- What each stand sells, in the order the Shop lists them.
local STANDS = {
	{ Kind = "Slingshot", Title = "Slingshot", Color = Color3.fromRGB(255, 120, 160) },
	{ Kind = "Egg", Title = "Eggs", Color = Color3.fromRGB(255, 205, 80) },
	{ Kind = "Luck", Title = "Luck", Color = Color3.fromRGB(110, 210, 110) },
	{ Kind = "Rebirth", Title = "Rebirth", Color = Color3.fromRGB(150, 110, 255) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "MenuGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if parent:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function attribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- Buttons squash a little when pressed.
local function bounce(target: GuiObject)
	local scale: UIScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = target
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Menu buttons
--------------------------------------------------------------------------------

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 16, 0.45, 0)
menu.Size = UDim2.fromOffset(200, 166)
menu.BackgroundTransparency = 1
menu.Parent = gui
if UserInputService.TouchEnabled then
	local small = Instance.new("UIScale")
	small.Scale = 0.75
	small.Parent = menu
end

local function menuButton(name: string, icon: string, color: Color3, y: number): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(0, y)
	button.Size = UDim2.fromOffset(190, 74)
	button.BackgroundColor3 = color
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = menu
	corner(button, UDim.new(0, 14))
	stroke(button, Color3.fromRGB(20, 20, 30), 4)

	label({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(58, 58),
		Text = icon,
		Parent = button,
	})
	local text = label({
		Position = UDim2.fromOffset(72, 12),
		Size = UDim2.new(1, -82, 1, -24),
		Text = name,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = button,
	})
	stroke(text, Color3.fromRGB(20, 20, 30), 3)

	-- Red circle in the corner: "!" or a count.
	local badge = label({
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = BADGE_COLOR,
		TextStrokeTransparency = 1,
		Text = "!",
		Visible = false,
		Parent = button,
	})
	corner(badge, UDim.new(1, 0))
	stroke(badge, Color3.new(1, 1, 1), 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = badge

	return button, badge
end

local shopButton, shopBadge = menuButton("Shop", "🛒", Color3.fromRGB(80, 210, 70), 0)
local indexButton, indexBadge = menuButton("Index", "📖", Color3.fromRGB(60, 170, 255), 90)

--------------------------------------------------------------------------------
-- Hint line along the top
--------------------------------------------------------------------------------

local hint = label({
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.new(0.7, 0, 0, 52),
	Text = "",
	TextStrokeTransparency = 1,
	Visible = false,
	Parent = gui,
})
stroke(hint, Color3.fromRGB(20, 20, 30), 4)
local hintSize = Instance.new("UITextSizeConstraint")
hintSize.MaxTextSize = 48
hintSize.Parent = hint

-- The most useful next step for the player, or nil.
local function currentHint(): string?
	if player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	if attribute("PetCount") == 0 then
		return "Hold the button to launch your egg!"
	end
	local coins = attribute("Coins")
	if coins >= Economy.rebirthCost(attribute("Rebirths")) then
		return "You can rebirth at the purple stand!"
	end
	local pedestalCost = Economy.pedestalCost(attribute("Pedestals"))
	if pedestalCost and coins >= pedestalCost and attribute("PetCount") > attribute("Pedestals") then
		return "Buy a new pedestal on your plot!"
	end
	for _, stand in STANDS do
		local field = Economy.UPGRADE_FIELDS[stand.Kind]
		local cost = field and Economy.upgradeCost(stand.Kind, attribute(field))
		if cost and coins >= cost then
			return `Upgrade your {stand.Title} at its stand!`
		end
	end
	return "Launch farther to hatch rarer pets!"
end

local function updateHint()
	local text = currentHint()
	if text == nil then
		hint.Visible = false
		return
	end
	if hint.Visible and hint.Text == text then
		return
	end
	hint.Text = text
	hint.Visible = true
	local scale: UIScale = hint:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = hint
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Panels
--------------------------------------------------------------------------------

local PANEL_SIZE = Vector2.new(720, 470)

local function makePanel(name: string, title: string): (Frame, TextLabel, UIScale)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.Visible = false
	panel.Parent = gui
	corner(panel, UDim.new(0, 24))
	stroke(panel, Color3.fromRGB(20, 20, 30), 5)
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local titleLabel = label({
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -110, 0, 44),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.Size = UDim2.fromOffset(48, 48)
	close.BackgroundColor3 = BADGE_COLOR
	close.Font = FONT
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = panel
	corner(close, UDim.new(1, 0))
	stroke(close, Color3.new(1, 1, 1), 3)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	return panel, titleLabel, scale
end

local indexPanel, indexTitle, indexScale = makePanel("IndexPanel", "Index")
local shopPanel, _shopTitle, shopScale = makePanel("ShopPanel", "Shop")

-- Shrink panels to fit small screens.
local fitScale = 1
local function fitPanels()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	fitScale = math.min(1, (screen.X - 24) / PANEL_SIZE.X, (screen.Y - 24) / PANEL_SIZE.Y)
	indexScale.Scale = fitScale
	shopScale.Scale = fitScale
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanels)
fitPanels()

-- Opens one panel (closing the other) with a little pop; pressing again closes it.
local function openPanel(panel: Frame, scale: UIScale)
	local wasOpen = panel.Visible
	indexPanel.Visible = false
	shopPanel.Visible = false
	if wasOpen then
		return
	end
	panel.Visible = true
	scale.Scale = fitScale * 0.7
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fitScale })
		:Play()
end

--------------------------------------------------------------------------------
-- Index
--------------------------------------------------------------------------------

local found: { [string]: boolean } = {}
local seenOnOpen: { [string]: boolean }? = nil -- what had been found when the Index was last opened
local cells: { [string]: { Circle: Frame, Ring: UIStroke, Mark: TextLabel, Name: TextLabel } } = {}
local zoneCounts: { [number]: TextLabel } = {}

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(16, 70)
list.Size = UDim2.new(1, -32, 1, -86)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = indexPanel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

for zoneIndex, zone in Config.Zones do
	local row = Instance.new("Frame")
	row.Name = zone.Name
	row.LayoutOrder = zoneIndex
	row.Size = UDim2.new(1, -12, 0, 92)
	row.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
	row.Parent = list
	corner(row, UDim.new(0, 14))

	label({
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.fromOffset(100, 34),
		Text = zone.Name,
		TextColor3 = zone.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	zoneCounts[zoneIndex] = label({
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.fromOffset(100, 24),
		Text = "0/7",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	for rarityIndex, rarity in Config.Rarities do
		local id = Pets.idFor(zoneIndex, rarityIndex)
		local cell = Instance.new("Frame")
		cell.Position = UDim2.fromOffset(116 + (rarityIndex - 1) * 78, 4)
		cell.Size = UDim2.fromOffset(74, 84)
		cell.BackgroundTransparency = 1
		cell.Parent = row

		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0)
		circle.Position = UDim2.new(0.5, 0, 0, 4)
		circle.Size = UDim2.fromOffset(50, 50)
		circle.BackgroundColor3 = UNKNOWN_COLOR
		circle.Parent = cell
		corner(circle, UDim.new(1, 0))
		local ring = stroke(circle, rarity.Color, 4)
		local mark = label({
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			Parent = circle,
		})
		local name = label({
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 0, 22),
			Text = "???",
			TextColor3 = rarity.Color,
			Parent = cell,
		})
		cells[id] = { Circle = circle, Ring = ring, Mark = mark, Name = name }
	end
end

local function refreshIndex()
	local total = 0
	for zoneIndex, zone in Config.Zones do
		local count = 0
		for rarityIndex in Config.Rarities do
			local id = Pets.idFor(zoneIndex, rarityIndex)
			local cell = cells[id]
			local def = Pets.ById[id]
			if found[id] then
				count += 1
				cell.Circle.BackgroundColor3 = zone.Color
				cell.Mark.Text = ""
				cell.Name.Text = if def then def.Name else id
			else
				cell.Circle.BackgroundColor3 = UNKNOWN_COLOR
				cell.Mark.Text = "?"
				cell.Name.Text = "???"
			end
		end
		zoneCounts[zoneIndex].Text = `{count}/{#Config.Rarities}`
		total += count
	end
	indexTitle.Text = `Index  {total}/{#Pets.All} found`
end

-- Badge: how many new pets were found since the Index was last opened.
local function refreshIndexBadge()
	local new = 0
	if seenOnOpen then
		for id in found do
			if not seenOnOpen[id] then
				new += 1
			end
		end
	end
	indexBadge.Text = tostring(new)
	indexBadge.Visible = new > 0
end

local function readFound()
	local text = player:GetAttribute("Discovered")
	found = {}
	if typeof(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			found[id] = true
		end
	end
	if seenOnOpen == nil and player:GetAttribute("DataLoaded") == true then
		-- Pets found in earlier sessions don't count as new.
		seenOnOpen = table.clone(found)
	end
	refreshIndex()
	refreshIndexBadge()
end
player:GetAttributeChangedSignal("Discovered"):Connect(readFound)
player:GetAttributeChangedSignal("DataLoaded"):Connect(readFound)
readFound()

indexButton.Activated:Connect(function()
	bounce(indexButton)
	seenOnOpen = table.clone(found)
	refreshIndexBadge()
	openPanel(indexPanel, indexScale)
end)

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

label({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -14),
	Size = UDim2.new(1, -48, 0, 26),
	Text = "Buy upgrades at the stands in the hub. Tap Show me to find one.",
	TextColor3 = Color3.fromRGB(200, 200, 220),
	Parent = shopPanel,
})

type ShopRow = { Level: TextLabel, Effect: TextLabel, Price: TextLabel }
local shopRows: { [string]: ShopRow } = {}

-- A glowing line from the player to a stand for a few seconds.
local guide: { Beam: Beam, Anchor: Part, Ends: number }? = nil
local function showMeTheWay(kind: string, color: Color3)
	if guide then
		guide.Beam:Destroy()
		guide.Anchor:Destroy()
		guide = nil
	end
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local stand = hub and hub:FindFirstChild(kind .. "Stand")
	local counter = stand and stand:FindFirstChild("Counter")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (counter and counter:IsA("BasePart") and root) then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = counter.Position + Vector3.new(0, 6, 0)
	anchor.Parent = workspace
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 1.5
	beam.Width1 = 1.5
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Parent = anchor
	beam.Destroying:Connect(function()
		a0:Destroy()
	end)
	local ends = os.clock() + 8
	guide = { Beam = beam, Anchor = anchor, Ends = ends }
	task.delay(8, function()
		if guide and guide.Ends == ends then
			guide.Anchor:Destroy()
			guide = nil
		end
	end)
end

for i, stand in STANDS do
	local row = Instance.new("Frame")
	row.Name = stand.Kind
	row.Position = UDim2.fromOffset(16, 70 + (i - 1) * 88)
	row.Size = UDim2.new(1, -32, 0, 80)
	row.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
	row.Parent = shopPanel
	corner(row, UDim.new(0, 14))

	local swatch = Instance.new("Frame")
	swatch.Position = UDim2.fromOffset(10, 10)
	swatch.Size = UDim2.fromOffset(60, 60)
	swatch.BackgroundColor3 = stand.Color
	swatch.Parent = row
	corner(swatch, UDim.new(0, 12))

	local level = label({
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.fromOffset(280, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local effect = label({
		Position = UDim2.fromOffset(82, 44),
		Size = UDim2.fromOffset(280, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 210, 230),
		Parent = row,
	})
	local price = label({ Position = UDim2.new(1, -310, 0, 22), Size = UDim2.fromOffset(160, 36), Parent = row })

	local go = Instance.new("TextButton")
	go.AnchorPoint = Vector2.new(1, 0.5)
	go.Position = UDim2.new(1, -12, 0.5, 0)
	go.Size = UDim2.fromOffset(130, 52)
	go.BackgroundColor3 = stand.Color
	go.Font = FONT
	go.TextScaled = true
	go.TextColor3 = Color3.new(1, 1, 1)
	go.Text = "Show me"
	go.Parent = row
	corner(go, UDim.new(0, 12))
	stroke(go, Color3.fromRGB(20, 20, 30), 3)
	local goPadding = Instance.new("UIPadding")
	goPadding.PaddingTop = UDim.new(0, 8)
	goPadding.PaddingBottom = UDim.new(0, 8)
	goPadding.Parent = go
	go.Activated:Connect(function()
		bounce(go)
		showMeTheWay(stand.Kind, stand.Color)
		shopPanel.Visible = false
	end)

	shopRows[stand.Kind] = { Level = level, Effect = effect, Price = price }
end

-- Fills in the Shop rows and returns whether anything is affordable now.
local function refreshShop(): boolean
	local coins = attribute("Coins")
	local anyAffordable = false
	for _, stand in STANDS do
		local row = shopRows[stand.Kind]
		local cost: number?
		if stand.Kind == "Rebirth" then
			local rebirths = attribute("Rebirths")
			cost = Economy.rebirthCost(rebirths)
			row.Level.Text = `Rebirth {rebirths}`
			row.Effect.Text = `Next: coins x{Format.number(Economy.rebirthMultiplier(rebirths + 1))}, keep your pets`
		else
			local level = attribute(Economy.UPGRADE_FIELDS[stand.Kind])
			cost = Economy.upgradeCost(stand.Kind, level)
			row.Level.Text = `{stand.Title}  Lv {level}`
			if stand.Kind == "Slingshot" then
				row.Effect.Text = `Power {math.floor(Economy.launchPower(level))} → {math.floor(Economy.launchPower(level + 1))}`
			elseif stand.Kind == "Egg" then
				row.Effect.Text = `Rare and up +{math.floor((Economy.eggBoost(level + 1) - 1) * 100 + 0.5)}%`
			else
				row.Effect.Text = `Mutations +{math.floor((Economy.luckBoost(level + 1) - 1) * 100 + 0.5)}%`
			end
		end
		if cost then
			local affordable = coins >= cost
			anyAffordable = anyAffordable or affordable
			row.Price.Text = `{Format.coins(cost)} coins`
			row.Price.TextColor3 = if affordable then GOOD_COLOR else BAD_COLOR
		else
			row.Price.Text = "Max level"
			row.Price.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	return anyAffordable
end

local function refreshShopAndBadge()
	shopBadge.Visible = refreshShop()
	updateHint()
end

for _, name in { "Coins", "SlingshotLevel", "EggLevel", "LuckLevel", "Rebirths", "Pedestals", "PetCount", "DataLoaded" } do
	player:GetAttributeChangedSignal(name):Connect(refreshShopAndBadge)
end
refreshShopAndBadge()

shopButton.Activated:Connect(function()
	bounce(shopButton)
	refreshShop()
	openPanel(shopPanel, shopScale)
end)
