--!strict
-- Placeholder client->server handlers.
--
-- Registers every C->S remote through RemoteGuard so the boundary exists from the
-- start, but the handlers do NOT implement fishing/economy/upgrades/aquarium yet
-- — they safely reject with a user-facing reason. Real services replace these in
-- later stages. Called synchronously from the bootstrap before any yielding init.

local RemoteGuard = require(script.Parent.RemoteGuard)
local ServerPush = require(script.Parent.ServerPush)

local Handlers = {}

function Handlers.registerAll()
	-- Fishing loop (RemoteEvents). The high-frequency inputs drop silently; the
	-- low-frequency cast tells the player the feature isn't available yet.
	RemoteGuard.registerEvent("RequestCast", function(player)
		ServerPush.notice(player, "not_implemented")
	end)
	RemoteGuard.registerEvent("FishingInput", function() end)
	RemoteGuard.registerEvent("FinishFishingRun", function() end)

	-- Request/response actions (RemoteFunctions) — always return { ok, reason }.
	RemoteGuard.registerFunction("PurchaseUpgrade", function()
		return { ok = false, reason = "not_implemented" }
	end)
	RemoteGuard.registerFunction("CollectAquarium", function()
		return { ok = false, reason = "not_implemented" }
	end)
	-- Snapshot polling handles its own readiness, so it does not require a ready
	-- profile at the boundary (it fails safe on its own until implemented).
	RemoteGuard.registerFunction("RequestPlayerSnapshot", function()
		return { ok = false, reason = "not_implemented" }
	end, { requireProfile = false })
end

return Handlers
