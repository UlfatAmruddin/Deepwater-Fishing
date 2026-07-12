# Asset-replacement contract

Deepwater Fishing separates **gameplay** from **visual assets** so production art can
replace any placeholder without editing gameplay code. Gameplay resolves the scene
through [`src/shared/SceneContract.luau`](../src/shared/SceneContract.luau), which finds
each contract point by its **CollectionService tag first** and the friendly **name second**.

## Non-negotiable rules

Gameplay **must not** depend on any of these — swapping a model would break them:

- ❌ mesh names or a specific model shape
- ❌ child indices / hierarchy position (`GetChildren()[2]`, "the third part")
- ❌ exact dimensions (`Size`) — size is styling, never logic
- ❌ a specific `PrimaryPart`

Gameplay **may** depend only on the stable contract below (tag → name → attribute).
Anything that is "presentation" is **anchored** and never moves; only the hook and
fish move, and only in the X/Y plane via `PlaneSpace` (fixed `Z = gameplayPlaneZ`).

## The contract surface

| Contract point | Tag | Fallback name | Kind | Gameplay reads | Must move? |
| --- | --- | --- | --- | --- | --- |
| Scene root | `DwScene` | `DeepwaterScene` | Model | container + `ContractVersion` attr | no |
| Camera pose | `DwCameraAnchor` | `CameraAnchor` | BasePart | its `CFrame` | no |
| Seat(s) | `DwBoatAnchor` | `BoatAnchor` | **Seat (Anchored)** | seats the player | no |
| Line origin | `DwHookOrigin` | `HookOrigin` | Attachment | its `WorldPosition` | no |
| Spawn(s) | `DwBoatSpawn` | `BoatSpawns/` | SpawnLocation | spawn point | no |
| Depth bands | `DwPlaneLayer` | `PlaneLayers/` | Folder | `Index/Z/YTop/YBottom` attrs | no |

The authoritative names/tags live in [`SceneConfig.luau`](../src/shared/Config/SceneConfig.luau)
(`tags`, `*Name`), and `scene/BuildScene.luau` mirrors them. The machine-readable per-role
contract is [`AssetManifest.luau`](../src/shared/Content/AssetManifest.luau).

## Verifying a replacement

1. Replace the model in Studio, keeping the required tags/attributes (below).
2. Press **Play** and read the Output. `SceneValidator` prints
   `Scene contract validated: DeepwaterScene` when the contract holds, or a specific
   warning per missing/broken point.
3. Confirm the player is seated, the camera is fixed, and movement is blocked — no code
   change should have been needed.

## Checklists

### Custom boat
- [ ] Contains a **Seat**, `Anchored = true`, tagged `DwBoatAnchor` (anchored seat keeps the
      seated character server-authoritative — the seated-immobile guarantee depends on it).
- [ ] Contains an **Attachment** tagged `DwHookOrigin`, positioned where the line pays out,
      on the gameplay plane (`Z = gameplayPlaneZ`).
- [ ] Every part `Anchored = true`; the boat is presentation only and never moves.
- [ ] A `DwBoatSpawn` SpawnLocation exists per boat (under `BoatSpawns/` or tagged).
- [ ] No reliance on `PrimaryPart`; any mesh/shape/size is fine.

### Custom fish
- [ ] Any model or icon — visual size maps from the fish's **normalized** size, not authored
      dimensions.
- [ ] Positioned only via `PlaneSpace` (X/Y, fixed `Z`). Never give it a free 3D trajectory.
- [ ] Carries no authoritative data; catches are resolved server-side.

### Custom prop (harbor decoration)
- [ ] `Anchored = true`, authored into `DeepwaterScene`.
- [ ] Stays within its visual `Z` layer; does not enter the gameplay plane unless it is a
      tagged gameplay object.

### Custom UI
- [ ] Restyle within the client `UI/` modules; UI is code-built into `PlayerGui` (no
      `StarterGui` authoring).
- [ ] All displayed values come from server snapshots — the UI computes no coins/catches.

## Adding a new contract point

1. Add its tag + fallback name to `SceneConfig.tags` / `SceneConfig.*Name` and the
   `Types.SceneConfig` / `Types.TagSet` types.
2. Add a resolver in `SceneContract` (tag-first, name-fallback, `IsA` type-checked) and an
   `audit()` check.
3. Emit it (tagged) from `scene/BuildScene.luau` and add an `AssetManifest` row.
4. Bump `ContractVersion` if the change is breaking.
