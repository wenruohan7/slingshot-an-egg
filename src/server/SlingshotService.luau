--!strict
-- Gives every player their slingshot each time they spawn and puts it in their
-- hand, and swaps it for the new model whenever they buy a better slingshot.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local SlingshotModel = require(Shared.SlingshotModel)

local SlingshotService = {}

local function slingshotLevel(player: Player): number
	local level = player:GetAttribute("SlingshotLevel")
	return if typeof(level) == "number" then level else 0
end

local function giveSlingshot(player: Player, character: Model)
	-- CharacterAdded can fire before the engine puts the character in Workspace
	-- (with Immediate signals), so wait for that, but not forever.
	local deadline = os.clock() + 10
	while character.Parent == nil and player.Character == character and os.clock() < deadline do
		task.wait()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if
		not (humanoid and humanoid:IsA("Humanoid") and backpack)
		or player.Character ~= character
		or not character:IsDescendantOf(workspace)
	then
		return
	end
	if character:FindFirstChild(SlingshotModel.NAME) or backpack:FindFirstChild(SlingshotModel.NAME) then
		return
	end

	local tool = SlingshotModel.buildTool(slingshotLevel(player))
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

-- Replaces the player's slingshot with the one for their current level,
-- keeping it in their hand if it was there.
local function swapSlingshot(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and backpack and humanoid) then
		return
	end
	local held = character:FindFirstChild(SlingshotModel.NAME)
	local stored = backpack:FindFirstChild(SlingshotModel.NAME)
	local old = held or stored
	if not old then
		return
	end
	local tool = SlingshotModel.buildTool(slingshotLevel(player))
	if old:IsA("Tool") and old.ToolTip == tool.ToolTip then
		tool:Destroy()
		return
	end
	old:Destroy()
	tool.Parent = backpack
	if held then
		humanoid:EquipTool(tool)
	end
end

function SlingshotService.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(giveSlingshot, player, character)
		end)
		player:GetAttributeChangedSignal("SlingshotLevel"):Connect(function()
			swapSlingshot(player)
		end)
		if player.Character then
			task.spawn(giveSlingshot, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return SlingshotService
