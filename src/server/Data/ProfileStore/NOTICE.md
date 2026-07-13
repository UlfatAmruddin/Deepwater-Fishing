# Vendored dependency: ProfileStore

- **Upstream:** https://github.com/MadStudioRoblox/ProfileStore
- **Source file:** `ProfileStore.luau` (vendored verbatim as `init.luau`)
- **Pinned commit:** `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (branch `main`; the
  project publishes no version tags, so we pin the exact commit)
- **Retrieved:** 2026-07-12
- **License:** Apache-2.0 — see [`LICENSE`](./LICENSE) in this folder
- **Author:** MAD STUDIO (loleris)

Vendored (NOT pulled via Wally) so the project keeps its offline/sandboxed build
and CI story. **Do not edit `init.luau`** — keep it pristine so it can be
re-synced from upstream.

It is excluded from our formatter/linter/type-checker (`.styluaignore`,
`selene.toml` `exclude`, and the CI `luau-lsp analyze --ignore`), since it is
third-party code held to its own standards.

All `DataStoreService` access is quarantined to `src/server/Data/` (this module
plus the ProfileStore-backed adapter). The CI DataStore-quarantine check allows
`src/server/Data/**` and fails on any reference elsewhere.

**Studio testing:** ProfileStore needs DataStore API access to work fully. In
Studio with **"Enable Studio Access to API Services" OFF** (Game Settings →
Security), `DataStoreState` becomes `NoAccess` and ProfileStore runs a degraded,
no-save mode — a profile loaded during the boot-time API probe can have its
session ended (the adapter uses the mock store, and PlayerData handles the
session-end cleanly). Enable API access on a published place for full behaviour;
the data-layer logic is otherwise fully covered by the headless tests
(`tests/ProfileSchema.spec`, `tests/SessionCore.spec`).

**To update:** re-fetch `ProfileStore.luau` at a newer pinned commit, update the
commit hash + date above, and re-run the data-layer tests.
