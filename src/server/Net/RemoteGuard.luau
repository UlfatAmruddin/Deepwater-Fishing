--!strict
-- The single client->server trust boundary.
--
-- Every C->S remote is registered through here. Per call it runs the pure gate
-- (rate limit -> payload shape -> profile readiness) BEFORE dispatching to the
-- owning service callback, isolates the callback in a pcall, and:
--   * RemoteEvents drop silently on reject (optionally push a Notice), and errors
--     are swallowed/logged — a bad payload can never crash the handler.
--   * RemoteFunctions ALWAYS return a { ok, reason } table (never yield-hang the
--     client, never leak an internal error).
-- Fishing/economy/state-specific validation lives in the service callbacks; this
-- layer only enforces the generic boundary and never trusts client input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Log = require(Shared.Util.Log)

local RateLimiter = require(script.Parent.RateLimiter)
local PayloadGuard = require(script.Parent.PayloadGuard)
local ServerPush = require(script.Parent.ServerPush)

local RemoteGuard = {}

export type EventHandler = (player: Player, payload: { [string]: any }) -> ()
export type FunctionHandler = (player: Player, payload: { [string]: any }) -> { [string]: any }

export type Options = {
	requireProfile: boolean?, -- default true; false lets the handler decide (e.g. snapshot polling)
	notifyOnReject: boolean?, -- push a Notice when a gated Event is rejected (non-rate reasons)
}

local DEFAULT_RATE: RateLimiter.Config = { capacity = 20, refillPerSecond = 20 }

local isReadyFn: ((Player) -> boolean)? = nil
local limiter: RateLimiter.RateLimiter? = nil

-- Wire dependencies + per-player rate-bucket cleanup. Call once, synchronously,
-- before registering any handlers and before any yielding initialization.
function RemoteGuard.start(deps: { isReady: (Player) -> boolean })
	isReadyFn = deps.isReady
	limiter = RateLimiter.new(DEFAULT_RATE)
	Players.PlayerRemoving:Connect(function(player)
		if limiter then
			limiter:clearPrefix(tostring(player.UserId) .. ":")
		end
	end)
end

local function rateKey(player: Player, name: string): string
	return tostring(player.UserId) .. ":" .. name
end

local function profileReady(player: Player): boolean
	local fn = isReadyFn
	return if fn then fn(player) else false
end

-- Run the shared gate. Payload is required to be a table (clients send {} for an
-- empty payload). Returns (allowed, reason?, payloadTable).
local function evaluate(
	player: Player,
	name: string,
	payload: any,
	requireProfile: boolean
): (boolean, string?, { [string]: any })
	local lim = limiter
	local rateOk = lim ~= nil and lim:allow(rateKey(player, name), os.clock())
	local payloadTable: { [string]: any } = if PayloadGuard.isTable(payload) then payload else {}
	local allowed, reason = PayloadGuard.gate({
		rateOk = rateOk,
		payloadOk = PayloadGuard.isTable(payload),
		profileReady = profileReady(player),
		requireProfile = requireProfile,
	})
	return allowed, reason, payloadTable
end

function RemoteGuard.registerEvent(name: string, handler: EventHandler, options: Options?)
	local opts: Options = options or {}
	local requireProfile = if opts.requireProfile ~= nil then opts.requireProfile else true
	local remote = Remotes.getEvent(name)
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		local allowed, reason, payloadTable = evaluate(player, name, payload, requireProfile)
		if not allowed then
			-- Events drop silently. Surface only non-spammy reasons as a Notice.
			if opts.notifyOnReject and reason ~= nil and reason ~= "rate_limited" then
				ServerPush.notice(player, reason)
			end
			return
		end
		-- xpcall (not pcall): the handler returns nothing, so pcall would type as a
		-- single return and the error would be uncatchable to log. A bad payload can
		-- never crash the connection.
		xpcall(handler, function(err)
			Log.warn("RemoteEvent handler error:", name, err)
		end, player, payloadTable)
	end)
end

function RemoteGuard.registerFunction(name: string, handler: FunctionHandler, options: Options?)
	local opts: Options = options or {}
	local requireProfile = if opts.requireProfile ~= nil then opts.requireProfile else true
	local remote = Remotes.getFunction(name)
	remote.OnServerInvoke = function(player: Player, payload: any)
		local allowed, reason, payloadTable = evaluate(player, name, payload, requireProfile)
		if not allowed then
			return PayloadGuard.reject(reason or "bad_request")
		end
		local ok, result = pcall(handler, player, payloadTable)
		if not ok then
			Log.warn("RemoteFunction handler error:", name, result)
			return PayloadGuard.reject("internal_error")
		end
		return result
	end
end

return RemoteGuard
