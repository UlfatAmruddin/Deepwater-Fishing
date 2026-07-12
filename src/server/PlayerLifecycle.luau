--!strict
-- Owns per-player server state and its full teardown.
--
-- Each player gets a session-scoped Cleanup ("trove") plus a fresh per-character
-- trove for every spawn. Character-scoped connections (the anchor's WalkSpeed
-- guard, seat re-seat, etc.) live on the character trove and are released on
-- respawn/death, so nothing accumulates across a session. When the player leaves,
-- both troves are destroyed and the state entry is dropped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cleanup = require(Shared.Util.Cleanup)
local Log = require(Shared.Util.Log)

local PlayerAnchor = require(script.Parent.Presentation.PlayerAnchor)
local PlayerData = require(script.Parent.Data.PlayerData)

type PlayerState = {
	player: Player,
	trove: Cleanup.Cleanup, -- session-scoped
	charTrove: Cleanup.Cleanup?, -- current character-scoped
}

local PlayerLifecycle = {}

local states: { [Player]: PlayerState } = {}

local function teardownCharacter(state: PlayerState)
	local charTrove = state.charTrove
	if charTrove then
		state.charTrove = nil
		charTrove:destroy()
	end
end

local function onCharacterAdded(state: PlayerState, character: Model)
	-- Release the previous character's connections before wiring the new one.
	teardownCharacter(state)

	local charTrove = Cleanup.new()
	state.charTrove = charTrove

	-- Anchoring waits for the Humanoid/root; do it off the signal thread. If the
	-- player leaves mid-wait, charTrove is destroyed and the anchor's late
	-- trove:add is cleaned immediately (Cleanup's destroyed-guard).
	task.spawn(PlayerAnchor.lock, state.player, character, charTrove)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end

	local trove = Cleanup.new()
	local state: PlayerState = { player = player, trove = trove, charTrove = nil }
	states[player] = state

	-- Data layer is a documented stub in Stage 0 (no DataStore calls yet).
	PlayerData.onPlayerAdded(player)

	trove:add(player.CharacterAdded:Connect(function(character)
		onCharacterAdded(state, character)
	end))
	trove:add(player.CharacterRemoving:Connect(function()
		teardownCharacter(state)
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
	teardownCharacter(state)
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
