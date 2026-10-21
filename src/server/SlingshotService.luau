--!strict
-- Gives every player a slingshot each time they spawn and puts it in their hand.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local SlingshotModel = require(Shared.SlingshotModel)

local SlingshotService = {}

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

	local tool = SlingshotModel.buildTool()
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

function SlingshotService.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(giveSlingshot, player, character)
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
