--!strict
-- The bow is not in the inventory: it appears in the player's hand only while
-- they stand on the shooting spot at the hub's front edge (Lane.isOnLaunchSpot),
-- and goes away when they walk off. It stays out while a shot is being drawn.
-- Whenever they buy a better bow, the next one that comes out is the new model.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Economy = require(Shared.Economy)
local Lane = require(Shared.Lane)
local SlingshotModel = require(Shared.SlingshotModel)

local SlingshotService = {}

local CHECK_EVERY = 0.1 -- seconds between checks of who is on the spot

-- Each player's bow, kept here (unparented) while they're off the spot.
local bows: { [Player]: Tool } = {}

local function slingshotLevel(player: Player): number
	local level = player:GetAttribute("SlingshotLevel")
	return if typeof(level) == "number" then level else 0
end

-- The player's bow for their current level, built if needed.
local function bowFor(player: Player): Tool
	local level = slingshotLevel(player)
	local tool = bows[player]
	if tool and tool.ToolTip == Economy.slingshot(level).Name then
		return tool
	end
	if tool then
		tool:Destroy()
	end
	local built = SlingshotModel.buildTool(level)
	bows[player] = built
	return built
end

-- Puts the bow in or out of the player's hand.
local function update(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if not character:IsDescendantOf(workspace) then
		return
	end
	-- Mid-draw the player is held in place, but keep the bow out regardless.
	local drawing = character:GetAttribute("ChargeStartedAt") ~= nil
	local wantBow = drawing or Lane.isOnLaunchSpot(root.Position)
	local tool = bows[player]
	local held = tool ~= nil and tool.Parent == character

	if wantBow and not held then
		tool = bowFor(player)
		-- Parenting a Tool to the character puts it straight into the hand.
		tool.Parent = character
	elseif not wantBow and held and tool then
		tool.Parent = nil
	end
end

-- Swaps the bow for the new model after a purchase, keeping it in the hand if it was.
local function swapBow(player: Player)
	local old = bows[player]
	if not old then
		return
	end
	local wasHeld = player.Character ~= nil and old.Parent == player.Character
	local tool = bowFor(player)
	if tool ~= old and wasHeld then
		tool.Parent = player.Character
	end
end

function SlingshotService.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- The old bow went away with the old character (or is unparented).
			local old = bows[player]
			if old then
				old:Destroy()
				bows[player] = nil
			end
		end)
		player:GetAttributeChangedSignal("SlingshotLevel"):Connect(function()
			swapBow(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local tool = bows[player]
		if tool then
			tool:Destroy()
		end
		bows[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(update, player)
			if not ok then
				warn(`[SlingshotService] {player.Name}: {err}`)
			end
		end
	end)
end

return SlingshotService
