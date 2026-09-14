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
- Unresolved issues: none in local validation; the post-push CI result is reported separately after the workflow run is observed.
- Commit: `chore: add project validation guardrails` (exact hash will be backfilled during the next context-maintenance task).
