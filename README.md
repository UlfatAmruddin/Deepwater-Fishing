# Deepwater Fishing

An original, social **2.5D fishing simulator** for Roblox — cast, steer, catch,
sell, upgrade. Built with 3D models but presented on a fixed X/Y plane with a
single fixed camera and a seated, anchored player.

> This is an original work. It is **not** affiliated with, and must not copy the
> name, branding, art, fish designs, UI, sounds, text, or implementation of any
> existing game.

## Status

**Stage 0 — project scaffold.** Tooling, Rojo project layout, the 2.5D
presentation contract (fixed camera + hard movement lock), and a reproducible
Studio scene. **No fishing or economy logic yet** — that arrives in later
stages (see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).

## Toolchain

Pinned in [`rokit.toml`](rokit.toml) and installed with:

```sh
rokit install
```

| Tool | Purpose |
| --- | --- |
| [Rojo](https://rojo.space) | Sync `src/` into Studio; build `.rbxl` |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | Formatting (`stylua src scene tests`) |
| [Selene](https://github.com/Kampfkarren/selene) | Linting (`selene src scene`) |
| [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | Type-checking / editor intelligence |
| [Lune](https://github.com/lune-org/lune) | Headless unit tests (`lune run tests/run`) |

**Wally** (package manager) is intentionally **deferred** until a dependency is
actually needed — first use will be pulling `ProfileStore` for the data layer.

> ⚠️ These tools ship only via GitHub Releases. In environments where
> github.com is blocked (some sandboxes/CI-less containers), `rokit install`
> fails and none of the commands above can run locally. The project still
> **builds and runs in Roblox Studio** via the Rojo plugin, and the
> [CI workflow](.github/workflows/ci.yml) runs the full format/lint/build/test
> pipeline on GitHub Actions, where releases are reachable.

## Development workflow

1. `rokit install` — get the toolchain (where GitHub is reachable).
2. Open a fresh Baseplate in Studio and build the scene once — see
   [`scene/README.md`](scene/README.md).
3. Install the **Rojo Studio plugin** (this is yours to install; it cannot be
   done from here).
4. `rojo serve` here, connect the plugin, and the `src/` tree syncs into the
   open place.
5. Press **Play** in Studio to test (the only place code actually runs).

### Handy commands

```sh
rojo build default.project.json --output build.rbxl   # produce a place file
stylua src scene tests                                 # format
selene generate-roblox-std && selene src scene         # lint
lune run tests/run                                     # headless tests
```

## Project layout

```
Deepwater-Fishing/
├─ rokit.toml               # toolchain pins
├─ default.project.json     # Rojo mapping (see docs/ARCHITECTURE.md)
├─ .luaurc                  # Luau strict mode
├─ stylua.toml / selene.toml
├─ .github/workflows/ci.yml # fmt + lint + build + test
├─ scene/                   # reproducible Studio scene builder + docs
├─ src/
│  ├─ shared/               # -> ReplicatedStorage.Shared (pure, dependency sink)
│  ├─ server/               # -> ServerScriptService.Server (authoritative)
│  └─ client/               # -> StarterPlayer.StarterPlayerScripts.Client
└─ tests/                   # headless Lune specs (pure logic only)
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the module map,
dependency rules, and the staged implementation plan.
