--!strict
-- Central networking registry.
--
-- All RemoteEvents/RemoteFunctions live under a single folder in
-- ReplicatedStorage so the client and server can never disagree on names.
-- No gameplay remotes are defined yet (Stage 0) — this is only the plumbing
-- that later stages register typed, server-validated handlers against.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

-- Wire-contract names land here as features arrive. Centralising them keeps
-- both sides honest about what may be sent.
Remotes.Events = {} :: { [string]: string }

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end

	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server only: ensure a RemoteEvent exists and return it.
function Remotes.registerEvent(name: string): RemoteEvent
	assert(RunService:IsServer(), "Remotes.registerEvent must be called on the server")

	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

-- Either side: fetch an already-registered RemoteEvent (creating on server).
function Remotes.getEvent(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		return (existing or Remotes.registerEvent(name)) :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
