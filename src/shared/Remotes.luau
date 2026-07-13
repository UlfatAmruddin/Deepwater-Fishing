--!strict
-- Central networking registry + name/type manifest.
--
-- `Remotes.Names` is the single source of truth for every remote: its kind
-- (RemoteEvent vs RemoteFunction) and direction. RemoteFunctions are
-- request/response and CLIENT->SERVER only; RemoteEvents carry the high-frequency
-- fishing loop and server->client pushes. The server creates the folder AND every
-- declared remote eagerly at boot (Remotes.init), so clients never wait on a
-- lazily-created remote; client lookups use a bounded WaitForChild.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

export type RemoteKind = "Event" | "Function"
export type RemoteDirection = "ClientToServer" | "ServerToClient"
export type RemoteSpec = { kind: RemoteKind, direction: RemoteDirection }

Remotes.Names = {
	-- Client -> Server: the fishing loop (Events) + request/response actions (Functions).
	RequestCast = { kind = "Event", direction = "ClientToServer" },
	FishingInput = { kind = "Event", direction = "ClientToServer" },
	FinishFishingRun = { kind = "Event", direction = "ClientToServer" },
	PurchaseUpgrade = { kind = "Function", direction = "ClientToServer" },
	CollectAquarium = { kind = "Function", direction = "ClientToServer" },
	RequestPlayerSnapshot = { kind = "Function", direction = "ClientToServer" },
	-- Server -> Client: pushes only (never a RemoteFunction).
	PlayerSnapshot = { kind = "Event", direction = "ServerToClient" },
	FishingState = { kind = "Event", direction = "ServerToClient" },
	RunResult = { kind = "Event", direction = "ServerToClient" },
	Notice = { kind = "Event", direction = "ServerToClient" },
} :: { [string]: RemoteSpec }

local function specFor(name: string): RemoteSpec
	local spec = Remotes.Names[name]
	assert(spec, ("Unknown remote '%s' — add it to Remotes.Names"):format(name))
	return spec
end

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

local function resolve(name: string, className: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote '{name}' did not replicate within {WAIT_TIMEOUT}s`)
	return remote
end

-- Server only: eagerly create the folder + every declared remote at boot.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init must be called on the server")
	for name, spec in Remotes.Names do
		resolve(name, if spec.kind == "Function" then "RemoteFunction" else "RemoteEvent")
	end
end

-- Either side: fetch a declared RemoteEvent (created on the server if missing).
function Remotes.getEvent(name: string): RemoteEvent
	assert(specFor(name).kind == "Event", ("Remote '%s' is not an Event"):format(name))
	return resolve(name, "RemoteEvent") :: RemoteEvent
end

-- Either side: fetch a declared RemoteFunction (created on the server if missing).
function Remotes.getFunction(name: string): RemoteFunction
	assert(specFor(name).kind == "Function", ("Remote '%s' is not a Function"):format(name))
	return resolve(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
