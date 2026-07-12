# Architecture

## Guiding rules

- **Server owns the truth.** Player data, fishing runs, catches, inventory,
  currency, upgrades, and purchases are all server-authoritative. The client
  sends *intents*; it is never trusted for coins, fish, depth, or catches.
- **Every RemoteEvent payload is hostile.** Types, ranges, ownership, state,
  and cooldowns are validated on the server before anything happens.
- **Explicit, one-way dependencies.** `client → shared ← server`. Client and
  server never require each other. `shared` never requires `client`/`server`.
  No circular requires.
- **Small modules**, Luau type annotations where practical, `task.*` (never the
  deprecated `wait`/`spawn`/`delay`), and every connection/per-player state is
  cleaned up on leave (see `shared/Util/Cleanup`).
- **DataStore access is quarantined** behind `server/Data/PlayerData`, which
  will use **ProfileStore** session locking. No other module may call
  `DataStoreService`.
- **No monetization yet.**

## Rojo mapping (`default.project.json`)

| Source path | Roblox location | Instance kind |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | Folder (no `init`) |
| `src/server` | `ServerScriptService.Server` | Script (`init.server.luau`) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | LocalScript (`init.client.luau`) |

`*.spec.luau` is excluded from the synced tree via `globIgnorePaths`; specs run
only under Lune. Because `src/server` and `src/client` contain an `init.*`
file, Rojo makes each root a script that requires its child ModuleScripts;
subfolders without an `init` become plain Folders.

## Module map (Stage 0)

### `src/shared` → `ReplicatedStorage.Shared`
- `Types.luau` — foundational presentation/config types (no gameplay types yet).
- `Remotes.luau` — networking plumbing; a single `Remotes` folder + register/get
  helpers. No gameplay remotes defined yet.
- `Config/GameConfig.luau` — tiny global constants (game name, data scope).
- `Config/SceneConfig.luau` — **source of truth** for the 2.5D layout: fixed
  camera pose, bounded pan, depth layers, boat anchor name.
- `Util/Cleanup.luau` — trove/maid for connection + state teardown.
- `Util/Log.luau` — tagged logger.
- `Util/Math.luau` — pure numeric helpers (unit-tested headlessly).

### `src/server` → `ServerScriptService.Server`
- `init.server.luau` — boots `PlayerLifecycle`.
- `PlayerLifecycle.luau` — per-player state + `Cleanup`; wires join/leave,
  routes character spawns to the anchor, calls the data hooks, and installs the
  `BindToClose` shutdown hook.
- `Presentation/PlayerAnchor.luau` — **server-authoritative** seat + immobilise
  (WalkSpeed/Jump = 0, disabled Humanoid states, anchored root). Cannot be
  overridden by a hacked client.
- `Data/PlayerData.luau` — **STUB**. The only future home of `DataStoreService`,
  backed by ProfileStore session locking. No DataStore calls in Stage 0.

### `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- `init.client.luau` — starts `InputLock` then `FixedCamera`.
- `Camera/FixedCamera.luau` — Scriptable camera, constant yaw/pitch/roll,
  bounded pan only.
- `Control/InputLock.luau` — disables the default control module and sinks all
  movement/jump/vehicle inputs.

## 2.5D presentation contract → where it lives

| Contract requirement | Enforced by |
| --- | --- |
| Fixed camera orientation, bounded pan only | `client/Camera/FixedCamera` (Scriptable, rotation forced to home each frame) |
| Player seated on a boat anchor | `server/Presentation/PlayerAnchor` + `scene/BuildScene` (`BoatAnchor` seat) |
| No walk/jump/swim/drive/free-camera/reposition | `PlayerAnchor` (server) + `InputLock` (client) |
| Gameplay locked to one X/Y plane, layered Z depth | `SceneConfig.gameplayPlaneZ` + `Layers/*` depth bands |
| Depth as vertical travel + layer changes | `SceneConfig.layers` (world-Y bands, parallax Z) |
| Small authored idle animations only | reserved for a later presentation stage |

## Data layer plan (Stage 3)

`server/Data/PlayerData` will:
- add **ProfileStore** (via Wally `MadStudioRoblox/ProfileStore`, or vendored),
- `StartSessionAsync` on join (session lock), load/init the profile schema,
- end the session on leave and in `BindToClose` (saves + releases the lock),
- wrap all store operations in `pcall`, with retry/backoff,
- remain the **only** module touching `DataStoreService`.

Everything else (currency, inventory, upgrades) reads/writes through the
in-memory profile that this layer owns.

## Staged implementation plan

- **Stage 0 — scaffold (this).** Tooling, Rojo, presentation contract,
  reproducible scene. No gameplay.
- **Stage 1 — architecture skeleton hardening.** Flesh out remotes registry,
  shared types, and lifecycle edge cases; add more headless tests.
- **Stage 2 — presentation polish.** Idle animations, layer visuals, depth
  travel feel.
- **Stage 3 — data layer.** ProfileStore session locking + profile schema.
- **Stage 4 — fishing run lifecycle.** Server state machine, cooldowns,
  validated cast/steer/descend intents.
- **Stage 5 — catch resolution.** Server RNG over depth-layered fish tables.
- **Stage 6 — economy.** Sell, currency, upgrades — all server-validated.
- **Stage 7 — UI/UX.** HUD + shop driven entirely by server state.
- **Stage 8 — hardening.** Anti-exploit pass, expanded tests, tuning.
