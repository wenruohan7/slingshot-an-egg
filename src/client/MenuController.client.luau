--!strict
-- The big menu buttons on the left (Shop and Index, with red badges), the hint
-- line along the top of the screen, and the two panels they open:
-- the Index (every pet, found or not) and the Shop, where every upgrade is bought.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local EggModel = require(Shared.EggModel)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)
local SlingshotModel = require(Shared.SlingshotModel)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(40, 40, 60)
local BADGE_COLOR = Color3.fromRGB(235, 50, 50)
local GOOD_COLOR = Color3.fromRGB(120, 230, 120)
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
		return "You can rebirth in the Shop!"
	end
	local pedestalCost = Economy.pedestalCost(attribute("Pedestals"))
	if pedestalCost and coins >= pedestalCost and attribute("PetCount") > attribute("Pedestals") then
		return "Buy a new pedestal on your plot!"
	end
	for _, stand in STANDS do
		local field = Economy.UPGRADE_FIELDS[stand.Kind]
		local level = field and attribute(field)
		local cost = level and Economy.upgradeCost(stand.Kind, level)
		if level and cost and coins >= cost then
			if stand.Kind == "Slingshot" then
				return `Open the Shop to buy the {Economy.slingshot(level + 1).Name}!`
			elseif stand.Kind == "Egg" then
				return `Open the Shop to buy the {Economy.egg(level + 1).Name}!`
			end
			return `Open the Shop to upgrade your {stand.Title}!`
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

-- Tabs along the top of the Shop, one per thing it sells.
local TABS = {
	{ Kind = "Slingshot", Title = "Slingshots" },
	{ Kind = "Egg", Title = "Eggs" },
	{ Kind = "Luck", Title = "Luck" },
	{ Kind = "Rebirth", Title = "Rebirth" },
}
local CARD_SIZE = Vector2.new(150, 300)

local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local refreshShop: () -> boolean

local function tabColor(kind: string): Color3
	for _, stand in STANDS do
		if stand.Kind == kind then
			return stand.Color
		end
	end
	return Color3.new(1, 1, 1)
end

local function showTab(kind: string)
	for tabKind, page in pages do
		page.Visible = tabKind == kind
		tabButtons[tabKind].BackgroundTransparency = if tabKind == kind then 0 else 0.6
	end
end

for i, tab in TABS do
	local button = Instance.new("TextButton")
	button.Name = tab.Kind .. "Tab"
	button.Position = UDim2.fromOffset(140 + (i - 1) * 132, 16)
	button.Size = UDim2.fromOffset(124, 40)
	button.BackgroundColor3 = tabColor(tab.Kind)
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = tab.Title
	button.Parent = shopPanel
	corner(button, UDim.new(0, 10))
	stroke(button, Color3.fromRGB(20, 20, 30), 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	button.Activated:Connect(function()
		bounce(button)
		showTab(tab.Kind)
	end)
	tabButtons[tab.Kind] = button

	local page = Instance.new("Frame")
	page.Name = tab.Kind .. "Page"
	page.Position = UDim2.fromOffset(16, 70)
	page.Size = UDim2.new(1, -32, 1, -86)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = shopPanel
	pages[tab.Kind] = page
end

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
	stroke(button, Color3.fromRGB(20, 20, 30), 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	return button
end

-- Sets a buy button for something with this price (nil = nothing left to buy).
local function setBuyButton(button: TextButton, cost: number?, coins: number)
	if cost == nil then
		button.Text = "Maxed"
		button.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
		button.AutoButtonColor = false
	elseif coins >= cost then
		button.Text = `Buy {Format.coins(cost)}`
		button.BackgroundColor3 = Color3.fromRGB(70, 200, 70)
		button.AutoButtonColor = true
	else
		button.Text = `{Format.coins(cost)} coins`
		button.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
		button.AutoButtonColor = false
	end
end

local function purchase(kind: string)
	Remotes.Purchase:FireServer(kind)
end

-- One card per slingshot or egg: a picture, its name, what it does, and a button.
type Card = { Button: TextButton, Frame: Frame }
local cards: { [string]: { Card } } = { Slingshot = {}, Egg = {} }

local function buildCards(kind: string, count: number, makeModel: (number) -> Instance, describe: (number) -> (string, string))
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new()
	list.Parent = pages[kind]
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for level = 0, count - 1 do
		local card = Instance.new("Frame")
		card.LayoutOrder = level
		card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		card.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
		card.Parent = list
		corner(card, UDim.new(0, 14))
		local cardStroke = stroke(card, Color3.fromRGB(20, 20, 30), 3)
		cardStroke.Name = "Outline"

		local viewport = Instance.new("ViewportFrame")
		viewport.Position = UDim2.fromOffset(5, 5)
		viewport.Size = UDim2.fromOffset(CARD_SIZE.X - 10, CARD_SIZE.X - 10)
		viewport.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
		viewport.Ambient = Color3.fromRGB(200, 200, 200)
		viewport.LightDirection = Vector3.new(-1, -1, -0.5)
		viewport.Parent = card
		corner(viewport, UDim.new(0, 12))
		local viewportCamera = Instance.new("Camera")
		viewportCamera.FieldOfView = 40
		viewportCamera.Parent = viewport
		viewport.CurrentCamera = viewportCamera
		makeModel(level).Parent = viewport
		frameViewport(viewport, viewportCamera)

		local name, effect = describe(level)
		label({ Position = UDim2.fromOffset(6, CARD_SIZE.X + 2), Size = UDim2.new(1, -12, 0, 30), Text = name, Parent = card })
		label({
			Position = UDim2.fromOffset(6, CARD_SIZE.X + 34),
			Size = UDim2.new(1, -12, 0, 26),
			Text = effect,
			TextColor3 = Color3.fromRGB(210, 210, 230),
			Parent = card,
		})
		local button = makeButton(card, UDim2.new(0, 10, 1, -58), UDim2.new(1, -20, 0, 48))
		button.Activated:Connect(function()
			bounce(button)
			if button.AutoButtonColor then
				purchase(kind)
			end
		end)
		table.insert(cards[kind], { Button = button, Frame = card })
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

-- Cards: owned ones say so, the one you have is outlined, the next one can be bought.
local function refreshCards(kind: string, coins: number): boolean
	local level = attribute(Economy.UPGRADE_FIELDS[kind])
	local affordable = false
	for i, card in cards[kind] do
		local cardLevel = i - 1
		local outline = card.Frame:FindFirstChild("Outline") :: UIStroke
		outline.Color = if cardLevel == level then GOOD_COLOR else Color3.fromRGB(20, 20, 30)
		outline.Thickness = if cardLevel == level then 5 else 3
		if cardLevel <= level then
			card.Button.Text = if cardLevel == level then "Equipped" else "Owned"
			card.Button.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
			card.Button.AutoButtonColor = false
		elseif cardLevel == level + 1 then
			local cost = Economy.upgradeCost(kind, level)
			setBuyButton(card.Button, cost, coins)
			affordable = cost ~= nil and coins >= cost
		else
			card.Button.Text = "Locked"
			card.Button.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
			card.Button.AutoButtonColor = false
		end
	end
	return affordable
end

-- Luck page: one upgrade with levels.
local luckLevel = label({ Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 0, 50), Parent = pages.Luck })
local luckEffect = label({
	Position = UDim2.fromOffset(20, 90),
	Size = UDim2.new(1, -40, 0, 34),
	TextColor3 = Color3.fromRGB(210, 210, 230),
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
	TextColor3 = Color3.fromRGB(210, 210, 230),
	Parent = pages.Rebirth,
})
local rebirthButton = makeButton(pages.Rebirth, UDim2.new(0.5, -130, 0, 170), UDim2.fromOffset(260, 64))
local rebirthArmedAt = 0
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

-- Fills in every page and returns whether anything is affordable now.
refreshShop = function(): boolean
	local coins = attribute("Coins")
	local anyAffordable = refreshCards("Slingshot", coins)
	anyAffordable = refreshCards("Egg", coins) or anyAffordable

	local level = attribute("LuckLevel")
	local luckCost = Economy.upgradeCost("Luck", level)
	luckLevel.Text = `Luck level {level} of {Economy.maxLevel("Luck")}`
	luckEffect.Text = `Mutations +{math.floor((Economy.luckBoost(level) - 1) * 100 + 0.5)}% now, +{math.floor(
		(Economy.luckBoost(level + 1) - 1) * 100 + 0.5
	)}% next`
	setBuyButton(luckButton, luckCost, coins)
	anyAffordable = anyAffordable or (luckCost ~= nil and coins >= luckCost)

	local rebirths = attribute("Rebirths")
	local rebirthCost = Economy.rebirthCost(rebirths)
	rebirthInfo.Text = `Rebirth {rebirths + 1}: coins x{Format.number(Economy.rebirthMultiplier(rebirths + 1))}`
	if os.clock() - rebirthArmedAt >= 3 then
		setBuyButton(rebirthButton, rebirthCost, coins)
		if rebirthButton.AutoButtonColor then
			rebirthButton.Text = `Rebirth {Format.coins(rebirthCost)}`
		end
	end
	return anyAffordable or coins >= rebirthCost
end

local function refreshShopAndBadge()
	shopBadge.Visible = refreshShop()
	updateHint()
end

for _, name in { "Coins", "SlingshotLevel", "EggLevel", "LuckLevel", "Rebirths", "Pedestals", "PetCount", "DataLoaded" } do
	player:GetAttributeChangedSignal(name):Connect(refreshShopAndBadge)
end
refreshShopAndBadge()

local function openShop(kind: string?)
	refreshShop()
	showTab(kind or "Slingshot")
	if not shopPanel.Visible then
		openPanel(shopPanel, shopScale)
	end
end

shopButton.Activated:Connect(function()
	bounce(shopButton)
	if shopPanel.Visible then
		shopPanel.Visible = false
	else
		openShop(nil)
	end
end)

-- The stands in the hub open the Shop on their own page.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local kind = prompt:GetAttribute("Kind")
	if typeof(kind) == "string" and pages[kind] then
		openShop(kind)
	end
end)
