--!strict
-- Finds the real models that were dropped into folders in ReplicatedStorage
-- (SlingshotModels, EggModels, StandModels, ...) and makes them safe to use.
--
-- Names are matched loosely: "Golden Egg", "Golden_Egg" and "golden egg" all
-- count, because Studio's 3D Importer names a model after its file and may
-- swap spaces for underscores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomModels = {}

local function simplify(name: string): string
	return (string.lower(name):gsub("[%s_%-]", ""))
end

-- The model named `name` in ReplicatedStorage[folderName], or nil.
function CustomModels.find(folderName: string, name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if not folder then
		return nil
	end
	local exact = folder:FindFirstChild(name)
	if exact then
		return exact
	end
	local wanted = simplify(name)
	for _, child in folder:GetChildren() do
		if simplify(child.Name) == wanted then
			return child
		end
	end
	return nil
end

-- Removes any scripts: free models often carry their own, and our code does the work.
function CustomModels.stripScripts(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy()
		end
	end
end

-- The one mesh in an import: the instance itself if it's a part, otherwise
-- the first part inside it (the 3D Importer wraps a mesh in a Model).
function CustomModels.mainPart(root: Instance): BasePart?
	if root:IsA("BasePart") then
		return root
	end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

-- Studio's 3D Importer can bring a mesh in with its axes swapped (lying on its
-- side, or turned a quarter). `size` is the mesh's own Size and `wanted` is the
-- size it should have in our model's space (from MeshSizes). Returns the
-- rotation that turns the mesh's own axes onto ours, picked by matching the
-- proportions of its sides, and the Size to give the mesh in its own axes.
-- A mesh that matches both ways round (like a turned-around bow) can't be told
-- apart by size; Config.Models has a setting to turn those.
local TURNS: { CFrame } = {}
for _, x in { 0, 1, 2, 3 } do
	for _, y in { 0, 1, 2, 3 } do
		for _, z in { 0, 1, 2, 3 } do
			local turn = CFrame.Angles(x * math.pi / 2, y * math.pi / 2, z * math.pi / 2)
			local duplicate = false
			for _, seen in TURNS do
				if seen.RightVector:FuzzyEq(turn.RightVector, 1e-3) and seen.UpVector:FuzzyEq(turn.UpVector, 1e-3) then
					duplicate = true
					break
				end
			end
			if not duplicate then
				table.insert(TURNS, turn)
			end
		end
	end
end

local function absVector(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

function CustomModels.fitRotation(size: Vector3, wanted: Vector3): (CFrame, Vector3)
	local best, bestError = CFrame.identity, math.huge
	local shape = wanted / math.max(wanted.Magnitude, 1e-6)
	for _, turn in TURNS do
		-- the mesh's sides as they'd lie in our space after this turn
		local turned = absVector(turn:VectorToWorldSpace(size))
		local err = (turned / math.max(turned.Magnitude, 1e-6) - shape).Magnitude
		-- prefer the smallest turn among ones that fit equally well
		local cost = err * 1000 - turn.RightVector.X - turn.UpVector.Y - turn.LookVector.Z
		if cost < bestError then
			best, bestError = turn, cost
		end
	end
	local ownSize = absVector(best:VectorToObjectSpace(wanted))
	return best, ownSize
end

-- The world-aligned box around every part in root: its low and high corners.
function CustomModels.bounds(root: Instance): (Vector3, Vector3)
	local lo = Vector3.one * math.huge
	local hi = -lo
	local parts: { Instance } = root:GetDescendants()
	table.insert(parts, root)
	for _, item in parts do
		if item:IsA("BasePart") then
			local half = item.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = item.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
						lo = lo:Min(corner)
						hi = hi:Max(corner)
					end
				end
			end
		end
	end
	return lo, hi
end

return CustomModels
