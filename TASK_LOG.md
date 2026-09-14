# Semarel Task Log

## 2026-09-14 — Faz 0: Repository and development environment

- Cloned the empty `GandalfTheGrayy/Semarel` repository into `C:\Dev\Semarelrepo` after the originally supplied `Semarelrepo` URL was found not to exist and the user selected `Semarel`.
- Created a minimal Godot 4.7.2 Standard/GDScript 2D bootstrap with a `Main -> World` hierarchy.
- Added restrained project directories, repository hygiene files, persistent Codex rules, current context, next-step, architecture, design, performance, and setup documentation.
- Added a non-blocking PowerShell tool checker for the required development toolchain.
- Kept gameplay systems out of scope; no terrain, NPC, kingdom, combat, or procedural-generation implementation was added.
- Validation: toolchain check, Godot headless editor import/parser validation, bounded main-scene launch, and Git status/diff review passed.
- Important decision: final resolution and terrain cell size remain intentionally undecided.
- Unresolved issues: none.
- Commit: `ac1d200528117703798290c932905f98a8b10c32`.

## Commit reference policy

The commit containing a task-log entry cannot include its own final hash. Record that task's commit subject in the entry, then backfill its exact hash during the next context-maintenance task. Do not create a circular follow-up commit solely to record a hash.

## 2026-09-14 — Faz 0.1: Development Guardrails

- Added `tools/validate.ps1` as the standard, CI-compatible project validation command.
- Added a GitHub Actions workflow that downloads the official Godot 4.7.2 Standard binary, verifies its checksum, and runs the same validation on `main` pushes and pull requests.
- Made setup and tool discovery portable through repository-relative paths, environment variables, and PATH-first lookup.
- Clarified validation rules in `AGENTS.md`, current guardrail status in `PROJECT_CONTEXT.md`, and the Faz 1 scope in `NEXT.md`.
- Validation: toolchain inventory, required-file checks, Godot headless import/parser validation, main-scene discovery, bounded runtime smoke test, YAML parse, and Git diff checks passed.
- Gameplay systems remained out of scope.
- GitHub Actions validation passed after the push.
- Unresolved issues: none.
- Commit: `330329b800ff1dcc7bacb4674b59f0e71aee8fd0` (`chore: add project validation guardrails`).

## 2026-09-14 — Faz 0.1 cleanup

- Removed the unexpected `.missing-localappdata/` artifact produced during validation hardening and confirmed it no longer reappears.
- GitHub Actions validation passed after the cleanup push.
- Commit: `952ef9f8ec2549dcac4e5a1e6b141c4e5c234122`.

## 2026-09-14 — Faz 1A: Authoritative World Data Foundation

- Added a data-only, chunked `WorldGrid` with centralized world/chunk/local coordinate handling and explicit world bounds behavior.
- Added scene-tree-independent `WorldChunkData` using a flat `PackedByteArray` terrain layer with 64×64-cell prototype chunks.
- Added placeholder terrain IDs solely to exercise the storage contract; no final terrain taxonomy was established.
- Added generic dirty-chunk tracking with clear and consume operations and no per-cell signal traffic.
- Added a 68-assertion headless suite covering storage size, first/last cells, boundary conversion, negative/outside behavior, partial edge chunks, terrain access, dirty isolation, dirty consumption, and data-only types.
- Integrated the suite into `tools/validate.ps1`, preserving the existing parser and runtime checks.
- Recorded a non-gating 256×256 data sanity baseline with 100,000 deterministic set/get pairs in `docs/PERFORMANCE.md`.
- Kept rendering, procedural generation, NPCs, navigation, save/load, and gameplay systems out of scope.
- Local validation passed with no parser errors or test failures; post-push CI status is reported after the workflow is observed.
- Unresolved issues: none in the implemented Faz 1A scope.
- Commit: `feat: establish authoritative world data foundation` (exact hash will be backfilled during the next context-maintenance task).
