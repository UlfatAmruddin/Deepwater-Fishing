--!strict
-- Owns per-player server state and its full teardown.
--
-- Each player gets a Cleanup ("trove") that collects their connections; when
-- they leave, everything is disconnected and the state entry is dropped so no
-- per-player state leaks. Character spawns are routed to PlayerAnchor, which
-- seats and immobilises them on the boat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cleanup = require(Shared.Util.Cleanup)
local Log = require(Shared.Util.Log)

local PlayerAnchor = require(script.Parent.Presentation.PlayerAnchor)
local PlayerData = require(script.Parent.Data.PlayerData)

type PlayerState = {
	player: Player,
	trove: Cleanup.Cleanup,
}

local PlayerLifecycle = {}

local states: { [Player]: PlayerState } = {}

local function onCharacterAdded(state: PlayerState, character: Model)
	-- Anchoring waits for the Humanoid/root; do it off the signal thread.
	task.spawn(PlayerAnchor.lock, state.player, character, state.trove)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end

	local trove = Cleanup.new()
	local state: PlayerState = { player = player, trove = trove }
	states[player] = state

	-- Data layer is a documented stub in Stage 0 (no DataStore calls yet).
	PlayerData.onPlayerAdded(player)

	trove:add(player.CharacterAdded:Connect(function(character)
		onCharacterAdded(state, character)
	end))

	if player.Character then
		onCharacterAdded(state, player.Character)
	end

	Log.info("Player joined:", player.Name)
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	state.trove:destroy()
	PlayerData.onPlayerRemoving(player)
	Log.info("Player left:", player.Name)
end

function PlayerLifecycle.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already present (e.g. live-reload during development).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Shutdown hook: the data layer flushes here in Stage 3. Kept now so the
	-- save-on-close pattern exists from the start.
	game:BindToClose(function()
		for player in states do
			PlayerData.onPlayerRemoving(player)
		end
	end)
end

return PlayerLifecycle
