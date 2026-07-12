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
  helpers. The folder is created eagerly at server boot; client lookups use a
  bounded `WaitForChild` that errors clearly instead of yielding forever. No
  gameplay remotes defined yet.
- `Config/GameConfig.luau` — tiny global constants (game name, data scope).
- `Config/SceneConfig.luau` — **source of truth** for the 2.5D layout: fixed
  camera pose, bounded pan, depth layers, boat anchor name.
- `Util/Cleanup.luau` — trove/maid for connection + state teardown.
- `Util/Log.luau` — tagged logger.
- `Util/Math.luau` — pure numeric helpers (unit-tested headlessly).

### `src/server` → `ServerScriptService.Server`
- `init.server.luau` — creates the `Remotes` folder, validates the scene, then
  boots `PlayerLifecycle`.
- `PlayerLifecycle.luau` — per-player state with a session-scoped `Cleanup` trove
  plus a fresh per-character trove each spawn; wires join/leave/respawn, routes
  character spawns to the anchor, calls the data hooks, and installs the
  `BindToClose` shutdown hook.
- `Presentation/PlayerAnchor.luau` — **server-authoritative** immobilise. Seats
  the humanoid on the boat Seat (`Seat:Sit`, with a re-seat guard) for the
  sitting pose, or hard-anchors the HumanoidRootPart if the anchor is not a Seat.
  Also zeros WalkSpeed/Jump and disables locomotion states. Cannot be overridden
  by a hacked client.
- `Scene/SceneValidator.luau` — boot-time diagnostics that warn (never error) if
  the authored scene is missing or has drifted from `SceneConfig`.
- `Data/PlayerData.luau` — **STUB**. The only future home of `DataStoreService`,
  backed by ProfileStore session locking. No DataStore calls in Stage 0; a CI
  guard fails the build if any other module references `DataStoreService`.

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
| Player seated on a boat anchor | `server/Presentation/PlayerAnchor` (`Seat:Sit` + re-seat guard; anchored-root fallback) + `scene/BuildScene` (`BoatAnchor` Seat) |
| No walk/jump/swim/drive/free-camera/reposition | `PlayerAnchor` (server) + `InputLock` (client) |
| Gameplay locked to one X/Y plane, layered Z depth | `SceneConfig.gameplayPlaneZ` + `PlaneLayers/*` depth bands |
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

---

# Confirmed target architecture (Prompt 01)

Confirmed after an adversarial design review (3 architects → synthesis → 3 critics).
Owner-approved decisions:

1. **ProfileStore** is **vendored** (pinned copy under `src/server/Data/`), not Wally — keeps
   offline/sandboxed CI and `rojo build` intact. The DataStore-quarantine CI grep widens to
   `src/server/Data/**` in the same change that vendors it (Stage 4), not later.
2. **8 boats/seats** authored by `BuildScene`; `Players.MaxPlayers = 8`; seat allocation is
   **session-scoped** (assigned on join, released on `PlayerRemoving`), doubling as the social row.
3. **Remotes:** RemoteFunctions (must always return `{ok, reason}`) for atomic request/response
   actions; RemoteEvents for the run loop; a **`Notice`** server→client event surfaces rejected
   fire-and-forget intents. No server→client RemoteFunction.
4. **Seat security (patched in Stage 0):** the character is server-authoritative because it is welded
   to the **Anchored** Seat; `PlayerAnchor` also calls `root:SetNetworkOwner(nil)` (no-ops when the
   seat is anchored, forces server ownership otherwise) and `SceneValidator` warns if the Seat is not
   anchored.
5. `Types` stays a single growing module; the 06A **CompositionConfig folds into
   `SceneConfig.planeBounds` + `PlaneSpace`** (no derived config module); UI is **code-built** into
   `PlayerGui` (no `StarterGui` authoring); services get dependencies **injected at the composition
   root** (`init.server`) so stages can land without out-of-order `require`s; a **Lune require-shim**
   makes dependency-bearing pure modules headless-testable.

## Module map (target)

`shared` (pure sink → ReplicatedStorage.Shared): `Types`, `Remotes` (+RemoteFunction +Names),
**`PlaneSpace`** (pure 2.5D math authority), `Config/{GameConfig, SceneConfig(+planeBounds),
BalanceConfig}`, `Content/{init(registry), Fish, Zones, Upgrades, Rarity, AssetManifest}`,
`Util/{Cleanup, Log, Math(+exponentialCost,+weightedIndex), Rng, Signal}`.

`server` (authoritative → ServerScriptService.Server): `init.server`, `PlayerLifecycle`,
`PlayerSnapshot` (pure projection+push), `ProfileGateway` (self-profile writes), `Analytics`(20),
`Net/{RateLimiter, RemoteGuard (the single C→S boundary), ServerPush (the single S→C sanitizer)}`,
`Data/{PlayerData(ProfileStore), ProfileSchema, Leaderboards(19)}` (DataStore quarantine),
`Presentation/PlayerAnchor` (seat pool + network-owner lock), `Scene/SceneValidator`,
`Fishing/{FishingService, FishGenerator(pure), FishingValidator(pure)}`,
`Economy/{EconomyService, Valuation(pure), UpgradeService, AquariumService, OfflineEarnings,
Monetization(24, gated)}`, `Zone/ZoneService`(18), `Social/SocialService`(19).

`client` (presentation only → StarterPlayer.StarterPlayerScripts.Client): `init.client`,
`Camera/FixedCamera`, `Control/{InputLock, InputMapper}`, `Composition/PlaneSpaceController`,
`Net/{ClientNet, ClientState}`, `Fishing/FishingController`, `Presentation/FeedbackController`,
`UI/{UiKit, Hud, ResultsUI, UpgradeShopUI, AquariumUI, ZoneUI, LeaderboardUI, SettingsUI, Tutorial}`.

## Remotes (single validation owner each)

`RemoteGuard` gates every client→server call: `profile-ready + ownership → rate-limit → payload
type/range/finite → pcall → dispatch`. RemoteEvents drop silently on reject; RemoteFunctions always
return `{ok=false, reason}`.

| Remote | Kind | Dir | Owner |
| --- | --- | --- | --- |
| RequestCast · FishingInput · FinishFishingRun | Event | C→S | FishingService |
| PurchaseUpgrade | Function | C→S | UpgradeService |
| CollectAquarium | Function | C→S | AquariumService |
| RequestPlayerSnapshot | Function | C→S | PlayerSnapshot |
| SelectZone · UnlockZone | Function | C→S | ZoneService (18) |
| AcknowledgeTutorial · UpdateSettings | Event/Fn | C→S | ProfileGateway (14) |
| JoinCoop · SetTitle · RequestSocialSnapshot | Fn | C→S | SocialService (19) |
| PlayerSnapshot · FishingState · RunResult · Notice · PresentationCue · SocialUpdate | Event | S→C | ServerPush |

`FishingState` carries per-encounter logical `{x, depth01}` so the client can render/steer (safe:
catches are reconstructed server-side from the seeded layout). `ServerPush` is the single place that
strips seed/weights/layout/world-Z.

## PlaneSpace (the plane lock)

Gameplay is two scalars — `x` (world-X, bounded by `SceneConfig.planeBounds`) and `depth` (normalized
0..1 → world-Y via the layer extents). **No `z` exists in the coordinate.** `planeToWorld` hard-stamps
`gameplayPlaneZ` (its signature has no z argument). The wire carries clamped scalar *intent*, never a
Vector3; the authoritative hook is integrated server-side on the plane; catches are server-reconstructed;
`PlayerAnchor` immobilises; `SceneValidator` warns on Z/anchor drift. The fixed camera is a **UX**
guarantee (client-side), not a security control — there is no camera→gameplay path.

## First playable vertical slice (MVP)

join seated → cast → steer in X/Y → catch → server coins → buy one upgrade → persists on rejoin.
Builds: shared foundation (incl. **Sunny Shallows Zone row + profile defaults `activeZone`/
`unlockedZones`** — required or every cast is rejected), `PlayerData` (real ProfileStore),
`Net/*`, `Fishing/*`, `Economy/{EconomyService, Valuation, UpgradeService(LineLength)}`, and client
`InputMapper`/`FishingController`/`Hud`/`ResultsUI`/`UpgradeShopUI`. Defers aquarium, offline, extra
zones, social, feedback, analytics, monetization, full tutorial, and the other three upgrades.

## Implementation order (prompt-pack aligned)

03 shared foundation → 04 PlayerData/ProfileStore (+ CI grep → `Data/**`) → 05 Net + race-safe boot
(register all C→S handlers **before** any yielding init) → 06/06A PlaneSpace + controller → 07
FishingService → 08 FishGenerator → 09 client presentation → 10 input → 11 validation → 12 economy →
13 upgrades **(MVP complete)** → 14 HUD/FTUE → 15 aquarium → 16 offline → 17 feedback → 18 zones →
19 social → 20 analytics → 21 tests → 22/23 harden+perf → 24 monetization (gated) → 25/26.
