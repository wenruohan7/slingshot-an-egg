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
local Lane = require(Shared.Lane)
local EggModel = require(Shared.EggModel)
local PetModel = require(Shared.PetModel)
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

-- A column of chunky square buttons on the left, each with a little 3D picture
-- that slowly turns and its name along the bottom. The coin and Luck counters
-- (HudController) sit just under the column, at the screen's middle.
local MENU_TILE = 104
local MENU_GAP = 14
local MENU_NAMES = { "Index", "Shop" }

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.AnchorPoint = Vector2.new(0, 1)
menu.Position = UDim2.new(0, 16, 0.5, -4)
menu.Size = UDim2.fromOffset(MENU_TILE + 10, #MENU_NAMES * (MENU_TILE + MENU_GAP))
menu.BackgroundTransparency = 1
menu.Parent = gui
if UserInputService.TouchEnabled then
	local small = Instance.new("UIScale")
	small.Scale = 0.75
	small.Parent = menu
end

type Spinner = { model: Instance, camera: Camera, centre: Vector3, distance: number }
local menuSpinners: { Spinner } = {}

-- Puts a model in a viewport and remembers how to turn the camera around it.
local function menuIcon(button: GuiObject, model: Instance)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.5, 0, 0, 4)
	viewport.Size = UDim2.new(1, -12, 1, -26)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1.5, -0.6)
	viewport.Parent = button
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport

	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local half = item.Size / 2
			low = low:Min(item.Position - half)
			high = high:Max(item.Position + half)
		end
	end
	if model:IsA("BasePart") then
		low = model.Position - model.Size / 2
		high = model.Position + model.Size / 2
	end
	if low.X == math.huge then
		return
	end
	local centre = (low + high) / 2
	local radius = (high - low).Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.0
	table.insert(menuSpinners, { model = model, camera = camera, centre = centre, distance = distance })
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i, spinner in menuSpinners do
		local angle = t * 0.8 + i * 2
		local offset = Vector3.new(math.cos(angle), 0.45, math.sin(angle)).Unit * spinner.distance
		spinner.camera.CFrame = CFrame.lookAt(spinner.centre + offset, spinner.centre)
	end
end)

local function menuButton(name: string, color: Color3, order: number, model: Instance?): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(4, (order - 1) * (MENU_TILE + MENU_GAP))
	button.Size = UDim2.fromOffset(MENU_TILE, MENU_TILE)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = menu
	corner(button, UDim.new(0, 20))
	stroke(button, Color3.fromRGB(20, 20, 30), 4)
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(Color3.fromRGB(75, 82, 110), Color3.fromRGB(38, 42, 60))
	fill.Rotation = 90
	fill.Parent = button

	-- A thin coloured ring just inside the edge, in the button's colour.
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -10, 1, -10)
	ring.BackgroundTransparency = 1
	ring.Parent = button
	corner(ring, UDim.new(0, 16))
	stroke(ring, color, 2.5).Transparency = 0.25

	if model then
		menuIcon(button, model)
	end

	local text = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 4, 0, 34),
		Text = name,
		ZIndex = 2,
		TextStrokeTransparency = 1,
		Parent = button,
	})
	stroke(text, Color3.fromRGB(20, 20, 30), 3.5)

	-- Red circle in the corner: "!" or a count.
	local badge = label({
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 3,
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

-- Pictures: a pet for the Index, a shiny egg for the Robux shop.
local indexPicture = PetModel.build({ Id = Pets.idFor(1, 3) }, CFrame.new())
local shopPicture = EggModel.build(5)
local indexButton, indexBadge = menuButton("Index", Color3.fromRGB(80, 170, 255), 1, indexPicture)
local shopButton = menuButton("Shop", Color3.fromRGB(255, 190, 60), 2, shopPicture) -- the Robux shop

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
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Lane.isOnLaunchSpot(root.Position) then
			return "Tap when the needle is at the top!"
		end
		return "Walk to the SHOOT HERE spot at the front!"
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
			end
			return `Visit the {shop.Title} to buy the {Economy.egg(level + 1).Name}!`
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
	return egg.Name, `{egg.Luck}x Luck`
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

-- Rebirth page: tap once to see the warning, tap again to rebirth.
local rebirthInfo = label({ Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 50), Parent = pages.Rebirth })
label({
	Position = UDim2.fromOffset(20, 80),
	Size = UDim2.new(1, -40, 0, 60),
	Text = "Resets your coins, bow and egg. You keep all your pets.",
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
for _, name in { "Coins", "SlingshotLevel", "EggLevel", "Rebirths", "Pedestals", "PetCount", "DataLoaded" } do
	player:GetAttributeChangedSignal(name):Connect(refreshShopAndHint)
end
refreshShopAndHint()
-- The first hint depends on where you stand (on the shooting spot or not).
task.spawn(function()
	while true do
		task.wait(0.5)
		updateHint()
	end
end)

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
-- A warm header, then sections: Featured (one big card per featured item, with
-- tiles showing what it does), Passes, and Coins (Buy 1 and Buy 3 buttons).

type RobuxItem = {
	Key: string,
	Name: string,
	Text: string,
	Icon: string,
	Price: number,
	Id: number,
	Featured: boolean?,
	Tiles: string?,
	Tag: string?,
	Price3: number?,
	Id3: number?,
}

local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local BUY_GREEN = Color3.fromRGB(80, 215, 70)
local BUY_LIP = Color3.fromRGB(40, 150, 40)
local GREY = Color3.fromRGB(110, 110, 130)
local GREY_LIP = Color3.fromRGB(70, 70, 90)
local HEADER_TOP = Color3.fromRGB(255, 205, 70)
local HEADER_BOTTOM = Color3.fromRGB(255, 150, 40)

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
end

-- The header bar: a warm gradient across the top of the panel, under the title
-- and the X. The bottom half is square so only the panel's top corners round.
do
	for _, part in { "Round", "Square" } do
		local bar = Instance.new("Frame")
		bar.Name = "Header" .. part
		bar.BorderSizePixel = 0
		bar.ZIndex = 0
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		if part == "Round" then
			bar.Size = UDim2.new(1, 0, 0, 76)
			corner(bar, UDim.new(0, 24))
			gradient(bar, HEADER_TOP, HEADER_BOTTOM)
		else
			bar.Position = UDim2.fromOffset(0, 38)
			bar.Size = UDim2.new(1, 0, 0, 38)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(HEADER_BOTTOM:Lerp(HEADER_TOP, 0.5), HEADER_BOTTOM)
			g.Rotation = 90
			g.Parent = bar
		end
		bar.Parent = robuxPanel
	end
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(0, 74)
	line.Size = UDim2.new(1, 0, 0, 4)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = DARK
	line.Parent = robuxPanel
	local title = robuxPanel:FindFirstChildOfClass("TextLabel")
	if title then
		stroke(title, DARK, 4)
		title.TextStrokeTransparency = 1
	end
end

local robuxList = Instance.new("ScrollingFrame")
robuxList.Name = "Items"
robuxList.Position = UDim2.fromOffset(14, 88)
robuxList.Size = UDim2.new(1, -28, 1, -100)
robuxList.BackgroundTransparency = 1
robuxList.BorderSizePixel = 0
robuxList.ScrollBarThickness = 8
robuxList.AutomaticCanvasSize = Enum.AutomaticSize.Y
robuxList.CanvasSize = UDim2.new()
robuxList.Parent = robuxPanel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = robuxList
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 8)
listPadding.Parent = robuxList

local robuxOrder = 0
local function nextOrder(): number
	robuxOrder += 1
	return robuxOrder
end

-- A section title in a dark pill between two lines: ——— Featured ———
local function divider(text: string)
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, -12, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = robuxList
	for _, side in { 0, 1 } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(side, 0.5)
		line.Position = UDim2.fromScale(side, 0.5)
		line.Size = UDim2.new(0.5, -120, 0, 4)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.fromRGB(90, 95, 120)
		line.Parent = row
		corner(line, UDim.new(1, 0))
	end
	local pill = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(210, 40),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(45, 50, 75),
		TextStrokeTransparency = 1,
		Text = text,
		Parent = row,
	})
	corner(pill, UDim.new(1, 0))
	stroke(pill, Color3.fromRGB(90, 95, 120), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 7)
	padding.PaddingBottom = UDim.new(0, 7)
	padding.Parent = pill
end

-- A chunky buy button: green with a darker lip under it, the Robux icon and the
-- price, and a small caption above ("Buy 1"). Returns the button and its parts.
type RobuxButton = { button: TextButton, lip: Frame, price: TextLabel, icon: ImageLabel }
local function robuxButton(parent: Instance, position: UDim2, size: UDim2, caption: string?): RobuxButton
	if caption then
		local captionLabel = label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = position + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, 0, -2),
			Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 26),
			Text = caption,
			TextStrokeTransparency = 1,
			Parent = parent,
		})
		stroke(captionLabel, DARK, 2.5)
	end
	local lip = Instance.new("Frame")
	lip.Position = position + UDim2.fromOffset(0, 6)
	lip.Size = size
	lip.BackgroundColor3 = BUY_LIP
	lip.Parent = parent
	corner(lip, UDim.new(0, 14))
	stroke(lip, DARK, 3)

	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = BUY_GREEN
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	corner(button, UDim.new(0, 14))
	stroke(button, DARK, 3)
	gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.BackgroundTransparency = 1
	icon.Image = ROBUX_ICON
	icon.Parent = button
	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.Parent = icon
	icon.Size = UDim2.fromScale(0.62, 0.62)

	local price = label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(1, -60, 0.7, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = button,
	})
	stroke(price, DARK, 3)
	return { button = button, lip = lip, price = price, icon = icon }
end

type RobuxEntry = { item: RobuxItem, isPass: boolean, id: number, price: number, parts: RobuxButton }
local robuxEntries: { RobuxEntry } = {}

local function setRobuxButton(parts: RobuxButton, text: string, active: boolean, showIcon: boolean)
	parts.price.Text = text
	parts.icon.Visible = showIcon
	parts.price.Size = if showIcon then UDim2.new(1, -60, 0.7, 0) else UDim2.new(1, -20, 0.6, 0)
	parts.price.TextXAlignment = if showIcon then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
	parts.price.AnchorPoint = if showIcon then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5)
	parts.price.Position = if showIcon then UDim2.new(1, -10, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
	parts.button.BackgroundColor3 = if active then BUY_GREEN else GREY
	parts.lip.BackgroundColor3 = if active then BUY_LIP else GREY_LIP
	parts.button.AutoButtonColor = active
end

local function refreshRobux()
	for _, entry in robuxEntries do
		if entry.isPass and player:GetAttribute("Pass_" .. entry.item.Key) == true then
			setRobuxButton(entry.parts, "Owned", false, false)
		elseif entry.id == 0 then
			setRobuxButton(entry.parts, "Coming soon", false, false)
		else
			setRobuxButton(entry.parts, tostring(entry.price), true, true)
		end
	end
end

local function addBuy(item: RobuxItem, isPass: boolean, id: number, price: number, parts: RobuxButton)
	parts.button.Activated:Connect(function()
		bounce(parts.button)
		if not parts.button.AutoButtonColor then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	table.insert(robuxEntries, { item = item, isPass = isPass, id = id, price = price, parts = parts })
	if isPass then
		player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(refreshRobux)
	end
end

-- The item's picture: its icon in a soft glowing circle.
local function iconBubble(parent: Instance, item: RobuxItem, size: number, x: number)
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0, 0.5)
	glow.Position = UDim2.new(0, x, 0.5, 0)
	glow.Size = UDim2.fromOffset(size, size)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.8
	glow.Parent = parent
	corner(glow, UDim.new(1, 0))
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.74, 0.74)
	inner.BackgroundColor3 = Color3.new(1, 1, 1)
	inner.BackgroundTransparency = 0.75
	inner.Parent = glow
	corner(inner, UDim.new(1, 0))
	label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		Text = item.Icon,
		TextStrokeTransparency = 1,
		Parent = glow,
	})
end

-- A small ribbon on the card's top-left corner.
local function ribbon(parent: Instance, text: string)
	local tag = label({
		Position = UDim2.fromOffset(-6, -8),
		Size = UDim2.fromOffset(130, 30),
		Rotation = -6,
		ZIndex = 3,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(235, 60, 70),
		TextStrokeTransparency = 1,
		Text = text,
		Parent = parent,
	})
	corner(tag, UDim.new(1, 0))
	stroke(tag, DARK, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke(tag, DARK, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = tag
end

local function shopCard(height: number, top: Color3, bottom: Color3): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = nextOrder()
	frame.Size = UDim2.new(1, -16, 0, height)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = robuxList
	corner(frame, UDim.new(0, 18))
	stroke(frame, DARK, 4)
	gradient(frame, top, bottom, 0)
	return frame
end

-- Tiles for the 2x Luck pass: how much more likely each rarity gets. Luck
-- multiplies a rarity's chance by Luck ^ (how rare it is, 0 to 1).
local function luckTiles(parent: Instance, position: UDim2, size: UDim2)
	local grid = Instance.new("Frame")
	grid.Position = position
	grid.Size = size
	grid.BackgroundTransparency = 1
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -6, 0.5, -5)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local count = #Config.Rarities
	local boost = Config.RobuxShop.LuckPassMultiplier
	for i = 2, count do -- Common never changes, so it gets no tile
		local rarity = Config.Rarities[i]
		local tile = Instance.new("Frame")
		tile.LayoutOrder = i
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		tile.BackgroundTransparency = 0.7
		tile.Parent = grid
		corner(tile, UDim.new(0, 10))
		stroke(tile, rarity.Color, 2).Transparency = 0.2
		local nameText = label({
			Position = UDim2.fromScale(0.06, 0.08),
			Size = UDim2.fromScale(0.88, 0.4),
			Text = rarity.Name,
			TextColor3 = rarity.Color,
			TextStrokeTransparency = 1,
			Parent = tile,
		})
		stroke(nameText, DARK, 2)
		local percent = math.floor((boost ^ ((i - 1) / (count - 1)) - 1) * 100 + 0.5)
		local pill = label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(0.9, 0, 0.46, 0),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(50, 160, 60),
			Text = `+{percent}%`,
			TextStrokeTransparency = 1,
			Parent = tile,
		})
		corner(pill, UDim.new(1, 0))
		stroke(pill, DARK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke(pill, DARK, 1.5)
	end
end

local function cardTitle(parent: Instance, item: RobuxItem, x: number, width: number, y: number)
	local nameText = label({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, 40),
		Text = item.Name,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = parent,
	})
	stroke(nameText, DARK, 3.5)
	local pitch = label({
		Position = UDim2.fromOffset(x, y + 42),
		Size = UDim2.fromOffset(width, 26),
		Text = item.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = parent,
	})
	stroke(pitch, DARK, 2.5)
end

-- Big featured card: picture, name, pitch, tiles, and the buy button on the right.
local function featuredCard(item: RobuxItem, isPass: boolean)
	local frame = shopCard(214, Color3.fromRGB(205, 140, 255), Color3.fromRGB(135, 80, 225))
	iconBubble(frame, item, 150, 14)
	cardTitle(frame, item, 178, 300, 12)
	if item.Tiles == "Luck" then
		luckTiles(frame, UDim2.fromOffset(178, 84), UDim2.new(1, -366, 0, 118))
	end
	local parts = robuxButton(frame, UDim2.new(1, -176, 0, 74), UDim2.fromOffset(160, 74), "Buy")
	addBuy(item, isPass, item.Id, item.Price, parts)
	if item.Tag then
		ribbon(frame, item.Tag)
	end
end

-- Regular card: picture, name and pitch, buy buttons on the right
-- (Buy 1 and Buy 3 when the item has a 3-pack).
local function itemCard(item: RobuxItem, isPass: boolean)
	local hasThree = item.Id3 ~= nil and item.Price3 ~= nil
	local frame = shopCard(if hasThree then 126 else 110, Color3.fromRGB(95, 175, 255), Color3.fromRGB(60, 110, 220))
	iconBubble(frame, item, 92, 10)
	local buttonsWidth = if hasThree then 296 else 150
	cardTitle(frame, item, 114, 640 - 114 - buttonsWidth - 30, if hasThree then 22 else 16)
	if hasThree then
		local three = robuxButton(frame, UDim2.new(1, -150, 0, 44), UDim2.fromOffset(136, 60), "Buy 3")
		addBuy(item, isPass, item.Id3 :: number, item.Price3 :: number, three)
		local one = robuxButton(frame, UDim2.new(1, -296, 0, 44), UDim2.fromOffset(136, 60), "Buy 1")
		addBuy(item, isPass, item.Id, item.Price, one)
	else
		local one = robuxButton(frame, UDim2.new(1, -150, 0.5, -26), UDim2.fromOffset(136, 60), nil)
		addBuy(item, isPass, item.Id, item.Price, one)
	end
	if item.Tag then
		ribbon(frame, item.Tag)
	end
end

local passes = (Config.RobuxShop.Passes :: any) :: { RobuxItem }
local products = (Config.RobuxShop.Products :: any) :: { RobuxItem }

local featured: { { item: RobuxItem, isPass: boolean } } = {}
for _, pass in passes do
	if pass.Featured then
		table.insert(featured, { item = pass, isPass = true })
	end
end
for _, product in products do
	if product.Featured then
		table.insert(featured, { item = product, isPass = false })
	end
end
if #featured > 0 then
	divider("Featured")
	for _, entry in featured do
		featuredCard(entry.item, entry.isPass)
	end
end
divider("Passes")
for _, pass in passes do
	if not pass.Featured then
		itemCard(pass, true)
	end
end
divider("Coins")
for _, product in products do
	if not product.Featured then
		itemCard(product, false)
	end
end
refreshRobux()

shopButton.Activated:Connect(function()
	bounce(shopButton)
	togglePanel(robuxPanel)
end)
