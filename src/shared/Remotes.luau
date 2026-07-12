--!strict
-- Central networking registry.
--
-- All RemoteEvents/RemoteFunctions live under a single folder in
-- ReplicatedStorage so the client and server can never disagree on names.
-- No gameplay remotes are defined yet (Stage 0) — this is only the plumbing
-- that later stages register typed, server-validated handlers against.
--
-- The server creates the folder eagerly at boot (Remotes.init), so a client
-- never waits on a lazily-created folder. Client lookups use a bounded
-- WaitForChild and raise a clear error instead of yielding forever.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

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

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, `Remotes folder '{FOLDER_NAME}' did not replicate within {WAIT_TIMEOUT}s`)
	return folder :: Folder
end

-- Server only: create the Remotes folder eagerly at boot so it always exists
-- before any client queries it. Call once from the server bootstrap.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init must be called on the server")
	getFolder()
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

	local event = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(event, `RemoteEvent '{name}' did not replicate within {WAIT_TIMEOUT}s`)
	return event :: RemoteEvent
end

return Remotes
