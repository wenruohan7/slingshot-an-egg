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
