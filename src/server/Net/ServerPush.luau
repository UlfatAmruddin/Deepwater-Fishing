--!strict
-- The single sanctioned server->client pusher.
--
-- Everything sent to a client goes through here, so it is the one place that
-- sanitizes outgoing payloads (Sanitizer strips seeds/weights/raw profiles/
-- world-Z/functions and deep-copies to break aliasing). Never sends a
-- RemoteFunction (S->C RemoteFunctions are forbidden).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Sanitizer = require(script.Parent.Sanitizer)
local Notice = require(script.Parent.Notice)

local ServerPush = {}

-- Fire a sanitized payload to one client over a server->client RemoteEvent.
function ServerPush.push(player: Player, remoteName: string, payload: { [string]: any })
	Remotes.getEvent(remoteName):FireClient(player, Sanitizer.sanitize(payload))
end

-- Push a safe, user-facing Notice built from an internal reason code.
function ServerPush.notice(player: Player, code: string)
	ServerPush.push(player, "Notice", Notice.build(code))
end

return ServerPush
