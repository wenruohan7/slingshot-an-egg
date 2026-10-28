--!strict
-- The big menu buttons on the left (Shop and Index, with red badges), the hint
-- line along the top of the screen, and the panels: the Index (every pet, found
-- or not), the Robux shop (the Shop button), and the shops in the hub, which
-- open while you stand in the zone in front of their stand.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local EggModel = require(Shared.EggModel)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)
local Shops = require(Shared.Shops)
local SlingshotModel = require(Shared.SlingshotModel)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(40, 40, 60)
local BADGE_COLOR = Color3.fromRGB(235, 50, 50)
local GOOD_COLOR = Color3.fromRGB(120, 230, 120)
local UNKNOWN_COLOR = Color3.fromRGB(70, 70, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "MenuGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

local shopButton = menuButton("Shop", "💎", Color3.fromRGB(80, 210, 70), 0) -- the Robux shop
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
		return "You can rebirth at the Rebirth stand!"
	end
	local pedestalCost = Economy.pedestalCost(attribute("Pedestals"))
	if pedestalCost and coins >= pedestalCost and attribute("PetCount") > attribute("Pedestals") then
		return "Buy a new pedestal on your plot!"
	end
	for _, shop in Shops.LIST do
		local field = Economy.UPGRADE_FIELDS[shop.Kind]
		local level = field and attribute(field)
		local cost = level and Economy.upgradeCost(shop.Kind, level)
		if level and cost and coins >= cost then
			if shop.Kind == "Slingshot" then
				return `Visit the {shop.Title} to buy the {Economy.slingshot(level + 1).Name}!`
			elseif shop.Kind == "Egg" then
				return `Visit the {shop.Title} to buy the {Economy.egg(level + 1).Name}!`
			end
			return `Visit the {shop.Title} to raise your Luck!`
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
local panels: { [Frame]: UIScale } = {}

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

	panels[panel] = scale
	return panel, titleLabel, scale
end

local indexPanel, indexTitle = makePanel("IndexPanel", "Index")
local robuxPanel = makePanel("RobuxPanel", "Shop")
local shopPanel, shopTitle = makePanel("ShopPanel", "")

-- Shrink panels to fit small screens.
local fitScale = 1
local function fitPanels()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	fitScale = math.min(1, (screen.X - 24) / PANEL_SIZE.X, (screen.Y - 24) / PANEL_SIZE.Y)
	for _, scale in panels do
		scale.Scale = fitScale
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanels)
fitPanels()

-- Opens one panel (closing the others) with a little pop.
local function showPanel(panel: Frame)
	if panel.Visible then
		return
	end
	for other in panels do
		other.Visible = false
	end
	panel.Visible = true
	local scale = panels[panel]
	scale.Scale = fitScale * 0.7
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fitScale })
		:Play()
end

-- Menu buttons: press once to open, again to close.
local function togglePanel(panel: Frame)
	if panel.Visible then
		panel.Visible = false
	else
		showPanel(panel)
	end
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
	togglePanel(indexPanel)
end)

--------------------------------------------------------------------------------
-- Shared bits for the shop panels
--------------------------------------------------------------------------------

local CARD_SIZE = Vector2.new(150, 290)
local CARD_GAP = 10
local HEADER_HEIGHT = 72
local DARK = Color3.fromRGB(20, 20, 30)
local CARD_COLOR = Color3.fromRGB(55, 55, 78)
local DIM_TEXT = Color3.fromRGB(210, 210, 230)

-- Points a viewport's camera at everything in it, from the front and a little above.
local function frameViewport(viewport: ViewportFrame, camera: Camera)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in viewport:GetDescendants() do
		if item:IsA("BasePart") then
			local half = item.Size / 2
			low = low:Min(item.Position - half)
			high = high:Max(item.Position + half)
		end
	end
	if low.X == math.huge then
		return
	end
	local centre = (low + high) / 2
	local radius = (high - low).Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(-0.75, 0.35, 0.55).Unit * distance, centre)
end

local function makeButton(parent: Instance, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = size
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = parent
	corner(button, UDim.new(0, 12))
	stroke(button, DARK, 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	return button
end

local function setButton(button: TextButton, text: string, color: Color3, active: boolean)
	button.Text = text
	button.BackgroundColor3 = color
	button.AutoButtonColor = active
end

-- Sets a buy button for something with this price (nil = nothing left to buy).
local function setBuyButton(button: TextButton, cost: number?, coins: number)
	if cost == nil then
		setButton(button, "Maxed", Color3.fromRGB(110, 110, 130), false)
	elseif coins >= cost then
		setButton(button, `Buy {Format.coins(cost)}`, Color3.fromRGB(70, 200, 70), true)
	else
		setButton(button, `{Format.coins(cost)} coins`, Color3.fromRGB(200, 80, 80), false)
	end
end

-- A row of cards that scrolls sideways.
local function cardRow(parent: Instance): ScrollingFrame
	local row = Instance.new("ScrollingFrame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 8
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

-- A card: a frame with the outline named "Outline" so it can be highlighted.
local function card(parent: Instance, order: number, size: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = CARD_COLOR
	frame.Parent = parent
	corner(frame, UDim.new(0, 14))
	stroke(frame, DARK, 3).Name = "Outline"
	return frame
end

--------------------------------------------------------------------------------
-- Shops in the hub: standing in a shop's zone opens its panel
--------------------------------------------------------------------------------

-- A coloured header behind the title, in the shop's colour, with your coins on the right.
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.ZIndex = 0
header.Parent = shopPanel
corner(header, UDim.new(0, 24))
local headerFill = Instance.new("Frame") -- squares off the header's bottom corners
headerFill.Position = UDim2.fromOffset(0, HEADER_HEIGHT / 2)
headerFill.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT / 2)
headerFill.BorderSizePixel = 0
headerFill.ZIndex = 0
headerFill.Parent = shopPanel
stroke(shopTitle, DARK, 3)
shopTitle.TextStrokeTransparency = 1

local shopCoins = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -80, 0, 18),
	Size = UDim2.fromOffset(240, 38),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextStrokeTransparency = 1,
	Parent = shopPanel,
})
stroke(shopCoins, DARK, 3)

local pages: { [string]: Frame } = {}
for _, shop in Shops.LIST do
	local page = Instance.new("Frame")
	page.Name = shop.Kind .. "Page"
	page.Position = UDim2.fromOffset(16, HEADER_HEIGHT + 14)
	page.Size = UDim2.new(1, -32, 1, -(HEADER_HEIGHT + 30))
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = shopPanel
	pages[shop.Kind] = page
end

local function purchase(kind: string)
	Remotes.Purchase:FireServer(kind)
end

-- Slingshot and Egg pages: one card per slingshot or egg, with a picture, its
-- name, what it does, and a button. Only the next one can be bought.
type Card = { Button: TextButton, Frame: Frame }
local cards: { [string]: { Card } } = { Slingshot = {}, Egg = {} }
local rows: { [string]: ScrollingFrame } = {}

local function buildCards(kind: string, count: number, makeModel: (number) -> Instance, describe: (number) -> (string, string))
	local row = cardRow(pages[kind])
	rows[kind] = row
	for level = 0, count - 1 do
		local frame = card(row, level, CARD_SIZE)

		local viewport = Instance.new("ViewportFrame")
		viewport.Position = UDim2.fromOffset(6, 6)
		viewport.Size = UDim2.fromOffset(CARD_SIZE.X - 12, CARD_SIZE.X - 12)
		viewport.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
		viewport.Ambient = Color3.fromRGB(200, 200, 200)
		viewport.LightDirection = Vector3.new(-1, -1, -0.5)
		viewport.Parent = frame
		corner(viewport, UDim.new(0, 12))
		local viewportCamera = Instance.new("Camera")
		viewportCamera.FieldOfView = 40
		viewportCamera.Parent = viewport
		viewport.CurrentCamera = viewportCamera
		makeModel(level).Parent = viewport
		frameViewport(viewport, viewportCamera)

		local name, effect = describe(level)
		label({ Position = UDim2.fromOffset(6, CARD_SIZE.X), Size = UDim2.new(1, -12, 0, 30), Text = name, Parent = frame })
		label({
			Position = UDim2.fromOffset(6, CARD_SIZE.X + 32),
			Size = UDim2.new(1, -12, 0, 24),
			Text = effect,
			TextColor3 = DIM_TEXT,
			Parent = frame,
		})
		local button = makeButton(frame, UDim2.new(0, 10, 1, -56), UDim2.new(1, -20, 0, 46))
		button.Activated:Connect(function()
			bounce(button)
			if button.AutoButtonColor then
				purchase(kind)
			end
		end)
		table.insert(cards[kind], { Button = button, Frame = frame })
	end
end

buildCards("Slingshot", #Config.Slingshots, function(level)
	return SlingshotModel.buildTool(level)
end, function(level)
	local slingshot = Economy.slingshot(level)
	return slingshot.Name, `Power x{Format.number(slingshot.Power)}`
end)

buildCards("Egg", #Config.Eggs, function(level)
	return EggModel.build(level)
end, function(level)
	local egg = Economy.egg(level)
	return egg.Name, `Rare+ odds x{Format.number(egg.Odds)}`
end)

-- Owned cards say so, the one you have is outlined green, the next one can be bought.
local function refreshCards(kind: string, coins: number)
	local level = attribute(Economy.UPGRADE_FIELDS[kind])
	for i, item in cards[kind] do
		local cardLevel = i - 1
		local outline = item.Frame:FindFirstChild("Outline") :: UIStroke
		outline.Color = if cardLevel == level then GOOD_COLOR else DARK
		outline.Thickness = if cardLevel == level then 5 else 3
		if cardLevel <= level then
			setButton(item.Button, if cardLevel == level then "Equipped" else "Owned", Color3.fromRGB(110, 110, 130), false)
		elseif cardLevel == level + 1 then
			setBuyButton(item.Button, Economy.upgradeCost(kind, level), coins)
		else
			setButton(item.Button, "Locked", Color3.fromRGB(80, 80, 100), false)
		end
	end
end

-- Scrolls so the card you have is first, with the next one beside it.
local function scrollToCurrent(kind: string)
	local row = rows[kind]
	local field = Economy.UPGRADE_FIELDS[kind]
	if row and field then
		row.CanvasPosition = Vector2.new(math.max(attribute(field) - 1, 0) * (CARD_SIZE.X + CARD_GAP), 0)
	end
end

-- Luck page: one upgrade with levels.
local luckLevel = label({ Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 0, 50), Parent = pages.Luck })
local luckEffect = label({
	Position = UDim2.fromOffset(20, 90),
	Size = UDim2.new(1, -40, 0, 34),
	TextColor3 = DIM_TEXT,
	Parent = pages.Luck,
})
local luckButton = makeButton(pages.Luck, UDim2.new(0.5, -120, 0, 160), UDim2.fromOffset(240, 64))
luckButton.Activated:Connect(function()
	bounce(luckButton)
	if luckButton.AutoButtonColor then
		purchase("Luck")
	end
end)

-- Rebirth page: tap once to see the warning, tap again to rebirth.
local rebirthInfo = label({ Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 50), Parent = pages.Rebirth })
label({
	Position = UDim2.fromOffset(20, 80),
	Size = UDim2.new(1, -40, 0, 60),
	Text = "Resets your coins, slingshot, egg and Luck. You keep all your pets.",
	TextColor3 = DIM_TEXT,
	Parent = pages.Rebirth,
})
local rebirthButton = makeButton(pages.Rebirth, UDim2.new(0.5, -130, 0, 170), UDim2.fromOffset(260, 64))
local rebirthArmedAt = 0
local refreshShop: () -> ()
rebirthButton.Activated:Connect(function()
	bounce(rebirthButton)
	if not rebirthButton.AutoButtonColor then
		return
	end
	if os.clock() - rebirthArmedAt < 3 then
		rebirthArmedAt = 0
		purchase("Rebirth")
	else
		rebirthArmedAt = os.clock()
		rebirthButton.Text = "Tap again!"
		task.delay(3, function()
			refreshShop()
		end)
	end
end)

-- Fills in every page with the latest prices and levels.
refreshShop = function()
	local coins = attribute("Coins")
	shopCoins.Text = `💰 {Format.coins(coins)}`
	refreshCards("Slingshot", coins)
	refreshCards("Egg", coins)

	local level = attribute("LuckLevel")
	local nextBoost = math.floor((Economy.luckBoost(level + 1) - 1) * 100 + 0.5)
	local boost = math.floor((Economy.luckBoost(level) - 1) * 100 + 0.5)
	luckLevel.Text = `Luck level {level} of {Economy.maxLevel("Luck")}`
	luckEffect.Text = if level < Economy.maxLevel("Luck")
		then `Mutations +{boost}% now, +{nextBoost}% next`
		else `Mutations +{boost}%`
	setBuyButton(luckButton, Economy.upgradeCost("Luck", level), coins)

	local rebirths = attribute("Rebirths")
	local rebirthCost = Economy.rebirthCost(rebirths)
	rebirthInfo.Text = `Rebirth {rebirths + 1}: coins x{Format.number(Economy.rebirthMultiplier(rebirths + 1))}`
	if os.clock() - rebirthArmedAt >= 3 then
		setBuyButton(rebirthButton, rebirthCost, coins)
		if rebirthButton.AutoButtonColor then
			rebirthButton.Text = `Rebirth {Format.coins(rebirthCost)}`
		end
	end
end

local function refreshShopAndHint()
	refreshShop()
	updateHint()
end
for _, name in { "Coins", "SlingshotLevel", "EggLevel", "LuckLevel", "Rebirths", "Pedestals", "PetCount", "DataLoaded" } do
	player:GetAttributeChangedSignal(name):Connect(refreshShopAndHint)
end
refreshShopAndHint()

local function openShop(shop: Shops.Shop)
	for kind, page in pages do
		page.Visible = kind == shop.Kind
	end
	shopTitle.Text = shop.Title
	header.BackgroundColor3 = shop.Color
	headerFill.BackgroundColor3 = shop.Color
	refreshShop()
	showPanel(shopPanel)
	scrollToCurrent(shop.Kind)
end

-- Step into a shop's zone and it opens; step out and it closes. Closing it
-- with X keeps it closed until you step out and back in.
local currentShop: Shops.Shop? = nil
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shop = if root and root:IsA("BasePart") then Shops.at(root.Position) else nil
	if shop == currentShop then
		return
	end
	currentShop = shop
	if shop then
		openShop(shop)
	elseif shopPanel.Visible then
		shopPanel.Visible = false
	end
end)

--------------------------------------------------------------------------------
-- Robux shop (the Shop button): game passes and coin packs
--------------------------------------------------------------------------------

type RobuxItem = { Key: string, Name: string, Text: string, Icon: string, Price: number, Id: number }
local ROBUX_CARD = Vector2.new(214, 176)

local robuxGrid = Instance.new("ScrollingFrame")
robuxGrid.Position = UDim2.fromOffset(16, 70)
robuxGrid.Size = UDim2.new(1, -32, 1, -86)
robuxGrid.BackgroundTransparency = 1
robuxGrid.BorderSizePixel = 0
robuxGrid.ScrollBarThickness = 8
robuxGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
robuxGrid.CanvasSize = UDim2.new()
robuxGrid.Parent = robuxPanel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(ROBUX_CARD.X, ROBUX_CARD.Y)
gridLayout.CellPadding = UDim2.fromOffset(12, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = robuxGrid

local robuxButtons: { { item: RobuxItem, isPass: boolean, button: TextButton } } = {}

local function refreshRobux()
	for _, entry in robuxButtons do
		if entry.isPass and player:GetAttribute("Pass_" .. entry.item.Key) == true then
			setButton(entry.button, "Owned", Color3.fromRGB(110, 110, 130), false)
		elseif entry.item.Id == 0 then
			setButton(entry.button, "Coming soon", Color3.fromRGB(80, 80, 100), false)
		else
			setButton(entry.button, `R$ {entry.item.Price}`, Color3.fromRGB(70, 200, 70), true)
		end
	end
end

local function addRobuxItem(item: RobuxItem, isPass: boolean, order: number)
	local frame = card(robuxGrid, order, ROBUX_CARD)
	frame.Size = UDim2.new() -- the grid sizes it
	label({ Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(52, 52), Text = item.Icon, Parent = frame })
	label({
		Position = UDim2.fromOffset(66, 12),
		Size = UDim2.new(1, -74, 0, 40),
		Text = item.Name,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	label({
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(1, -20, 0, 48),
		Text = item.Text,
		TextColor3 = DIM_TEXT,
		TextWrapped = true,
		Parent = frame,
	})
	local button = makeButton(frame, UDim2.new(0, 12, 1, -58), UDim2.new(1, -24, 0, 46))
	button.Activated:Connect(function()
		bounce(button)
		if not button.AutoButtonColor then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end
	end)
	table.insert(robuxButtons, { item = item, isPass = isPass, button = button })
	if isPass then
		player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(refreshRobux)
	end
end

for i, pass in Config.RobuxShop.Passes do
	addRobuxItem(pass, true, i)
end
for i, product in Config.RobuxShop.Products do
	addRobuxItem(product, false, 100 + i)
end
refreshRobux()

shopButton.Activated:Connect(function()
	bounce(shopButton)
	togglePanel(robuxPanel)
end)
