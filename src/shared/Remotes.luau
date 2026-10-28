--!strict
-- Network events between client and server. The server creates them,
-- the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"ChargeStart", -- client -> server: player pressed the launch button
	"ChargeRelease", -- client -> server: player let go
	"EggLaunched", -- server -> client: (egg, stageName) the egg is in the air
	"EggLanded", -- server -> client: (zoneIndex, stageName, distance)
	"EggHatched", -- server -> client: (egg, pet, merged, kept, isNew) what came out of your egg
	"BigHatch", -- server -> all clients: (playerName, position, pet) a rare hatch everyone sees
	"Purchase", -- client -> server: (kind) buy the next "Slingshot" or "Egg", or "Rebirth"
	"Notice", -- server -> client: (text, kind) a short message, kind is "good", "error", "info" or "rebirth"
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
