# Scene setup (2.5D presentation)

The playable scene is **authored data**, not synced code. Rojo injects the
scripts under `src/`; the boat, water, camera anchor, and depth layers live in
the place file. `BuildScene.luau` makes that authored scene **reproducible** so
anyone can regenerate it from a fresh Baseplate without hand-placing parts.

> These steps run inside Roblox Studio, which **cannot be executed from this
> repository/CI**. They are the manual, human-verified part of setup. Nothing
> here has been run by the tooling — treat the checklist below as *unverified
> until you perform it in Studio*.

## Regenerate the scene

1. Open a **fresh Baseplate** in Roblox Studio (`File > New`, choose
   *Baseplate*).
2. Open the command bar (`View > Command Bar`).
3. Paste the **entire** contents of [`BuildScene.luau`](./BuildScene.luau) and
   press <kbd>Enter</kbd>.
4. Confirm the output: `[Deepwater] Built 'DeepwaterScene' with 4 depth layers...`
5. `File > Save to File` (or Publish) to persist the place.

The script is **idempotent** — running it again destroys the old
`DeepwaterScene` and rebuilds it, so it is safe to iterate.

## What it builds (`Workspace.DeepwaterScene`)

| Instance | Type | Purpose |
| --- | --- | --- |
| `CameraAnchor` | Part (invisible) | Its `CFrame` is the fixed camera pose the client reads |
| `Boat/Hull` | Part (anchored) | The boat body |
| `Boat/BoatAnchor` | Seat (anchored) | The seat point the server anchors the player to |
| `BoatSpawn` | SpawnLocation | Players spawn seated on the boat |
| `Water` | Part (anchored, non-colliding) | Visual water column |
| `Layers/<Surface..Deepwater>` | Folder | One per depth band; carries `Index`/`Z`/`YTop`/`YBottom` attributes + a visual `Band` |

The layout mirrors `src/shared/Config/SceneConfig.luau`, which is the runtime
source of truth. **If you change values in one, change them in the other.**

## Baseplate → Deepwater conversion notes

`BuildScene.luau` performs the conversion for you:

- removes the default flat `Baseplate` part,
- removes any stray `SpawnLocation`s and adds the on-boat `BoatSpawn`,
- disables `Workspace.StreamingEnabled` (the scene is small and fully authored),
- sets harbor-mood `Lighting`.

## Manual verification checklist (do this in Studio)

Once the scripts are synced and you press **Play**:

- [ ] The camera is fixed — mouse/right-drag does **not** rotate it; only a
      small bounded pan follows the cursor.
- [ ] `WASD`, arrows, and <kbd>Space</kbd> do **nothing**; the avatar never
      walks or jumps.
- [ ] The avatar is seated on the boat and cannot be moved or repositioned.
- [ ] Output shows the server anchor + client boot logs
      (`[Deepwater] Anchored player to boat`, `[Deepwater] Client ready.`).
- [ ] `Workspace.DeepwaterScene.Layers` contains four folders with the
      expected attributes.
