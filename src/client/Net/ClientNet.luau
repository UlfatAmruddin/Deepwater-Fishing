--!strict
-- Thin client-side networking helper.
--
-- Wraps the shared Remotes manifest so client code fires/invokes/listens by name
-- without touching remote instances directly. The server is authoritative — this
-- layer sends requests and receives pushes, it makes no trust decisions. Every
-- payload is a table (send {} when there is nothing to send).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ClientNet = {}

-- Fire a client->server RemoteEvent (the fishing loop). Never yields.
function ClientNet.fire(name: string, payload: { [string]: any }?)
	Remotes.getEvent(name):FireServer(payload or {})
end

-- Invoke a client->server RemoteFunction and return its { ok, reason?, ... }
-- response. Yields until the server replies.
function ClientNet.invoke(name: string, payload: { [string]: any }?): { [string]: any }
	local result = Remotes.getFunction(name):InvokeServer(payload or {})
	if type(result) == "table" then
		return result
	end
	-- The server always returns a table, but stay defensive against a nil/hang.
	return { ok = false, reason = "internal_error" }
end

-- Listen to a server->client RemoteEvent push. Returns the RBXScriptConnection.
function ClientNet.on(
	name: string,
	callback: (payload: { [string]: any }) -> ()
): RBXScriptConnection
	return Remotes.getEvent(name).OnClientEvent:Connect(function(payload: any)
		callback(if type(payload) == "table" then payload else {})
	end)
end

return ClientNet
