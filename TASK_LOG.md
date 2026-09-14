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
- Local validation passed with no parser errors or test failures.
- GitHub Actions validation passed after the authenticated release-download fix.
- Unresolved issues: none in the implemented Faz 1A scope.
- Main implementation commit: `a058a0ef11ce80a26924db1a84c5ef67b7664070` (`feat: establish authoritative world data foundation`).
- CI reliability commits: `dfa748fbe8c1f0c013c1cbefd7aca1abcd0b7765` and `ef917f99303b87bf774a58b7c117ca6964c3d3ac`.

## 2026-09-14 — Faz 1B: Terrain Visualization & World Inspection

- Added clipped chunk geometry and copied terrain-snapshot read APIs without exposing mutable authoritative storage.
- Added a presentation-only debug palette, data-to-`Image` rasterizer, chunk-scaled renderer, read-only mouse inspector, and deterministic preview fixture.
- Kept the renderer rebuildable from `WorldGrid`; one 256×256 preview uses 16 chunk sprites rather than per-cell Nodes.
- Preserved dirty-state ownership outside the renderer: selected chunks can refresh without consuming the shared dirty set.
- Added 42 headless presentation assertions alongside the preserved 80 world-data assertions, including partial-edge, palette, fallback, immutability, texture reuse, rebuild, and inspector contracts.
- Interactive OpenGL inspection confirmed visible terrain, correct debug colors, gap-free chunk joins, sharp nearest-neighbor scaling, correct cell/chunk/local data, and explicit outside-world reporting.
- Added explicit workflow wiring for the repository-scoped `${{ github.token }}` while retaining `contents: read`, retries, and SHA-256 verification.
- Production art, procedural generation, gameplay mutation, navigation, NPCs, and Faz 1C propagation remained out of scope.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 1B scope.
- Commit: `e1a4c0a1fb48f01d17f1ccd90a66129ece08d030` (`feat: add terrain visualization and inspection`).

## 2026-09-14 — Faz 1C: Generic World Change Propagation & Incremental Refresh

- Added immutable-by-contract `WorldChangeSet` snapshots containing a committed revision and terrain-chunk invalidations only.
- Replaced destructive dirty consumption with pending accumulation plus `WorldGrid.commit_changes()`; non-empty commits advance revision and empty commits do not.
- Sorted terrain chunks deterministically by y then x, deduplicated same-chunk changes, and returned copied collections to every consumer.
- Migrated `TerrainRenderer` to `apply_world_changes()` so it refreshes only listed chunks without changing the batch, pending state, revision, or authoritative terrain.
- Added a SPACE-key debug probe that deterministically changes four cells spanning four chunks, commits one batch, and updates renderer plus revision/chunk-count UI.
- Added a dedicated 44-assertion world change-set suite while preserving the 75-assertion world-data and 42-assertion visualization suites.
- Interactive OpenGL checks confirmed revisions 1→2→3, four changed chunks per debug batch, LAND→ROCK→SAND inspection, targeted refresh, sharp filtering, and gap-free rendering.
- Kept the change set as chunk-level invalidation metadata; no gameplay event bus, full cell diff, navigation, save/streaming, climate, or other future consumer was implemented.
- Local parser/import, runtime smoke, and all three headless suites passed.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 1C scope.
- Commit: `3ed5ebb662771e861b0cee4f9a158bf0d46e4ef9` (`feat: add generic world change propagation`).

## 2026-09-14 — Faz 1D: Second Logical World Layer Extensibility Probe

- Added prototype elevation as a second independent flat `PackedByteArray` in each `WorldChunkData`, separate from terrain and with no per-cell Objects.
- Added bounded elevation get/set/fill/copy APIs through `WorldChunkData` and `WorldGrid`, reusing the existing world/chunk/local coordinate path.
- Added independent pending elevation chunk tracking; terrain and elevation mutations do not mark one another, while a mixed commit advances the single global revision once.
- Extended immutable-by-contract `WorldChangeSet` snapshots with a separate, y-then-x sorted elevation chunk category.
- Kept `TerrainRenderer` terrain-only; elevation-only committed batches update its observed revision without refreshing or changing terrain images.
- Added a dedicated 86-assertion layer-extensibility suite covering storage independence, values/bounds, 65×65 partial edges, deduplication, layered commits, immutable snapshots, stability, and presentation independence.
- Preserved the 75-assertion world-data, 42-assertion terrain-visualization, and 44-assertion change-set suites.
- Documented the 131,072-byte raw terrain-plus-elevation array estimate for a 256×256 prototype world, excluding container/object overhead and without defining a target.
- Kept elevation precision and gameplay meaning undecided; no visualization, generation, slope, hydrology, pathfinding, biome, or generic layer framework was added.
- Local parser/import, runtime smoke, and all four headless suites passed.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 1D scope.
- Commit: `39da3b600c9a2d45d3aaedb22546e46c80a445f8` (`feat: prove multi-layer world data extensibility`).

## 2026-09-14 — Faz 1E: Secondary Layer Visualization & Inspection Probe

- Added a separate `ElevationOverlayRenderer` that rebuilds exclusively from copied elevation snapshots and clips images through authoritative chunk world rectangles.
- Added deterministic 0–255 grayscale rasterization, presentation-only 58% opacity, shared prototype display scale, nearest filtering, and terrain-above/below z-ordering.
- Kept terrain and elevation presentation explicit: each renderer reads only its own `WorldChangeSet` category and neither stores or mutates authoritative layer data.
- Extended the deterministic debug fixture with a simple x/y elevation gradient; its initial commit is one mixed terrain/elevation batch, not production generation.
- Added the `E` debug toggle, unitless elevation to `WorldInspector`, and elevation chunk counts to the existing change summary without creating a map-mode or input framework.
- Added small per-chunk refresh-count inspection hooks and a dedicated 61-assertion elevation-visualization suite covering rasterization, partial edges, alignment, authority, lifecycle, toggle, category isolation, mixed consumers, fixture, and inspector contracts.
- Preserved the 75-assertion world-data, 42-assertion terrain-visualization, 44-assertion change-set, and 86-assertion layer-extensibility suites.
- Interactive OpenGL checks confirmed overlay off/on behavior, unitless `elevation: 129` inspection, sharp aligned gradient rendering, gap-free chunk joins, and the existing SPACE terrain probe at revision 2 with zero elevation chunk invalidations.
- Fixed the inspector/help layout overlap found during visual inspection and removed all temporary capture artifacts.
- No elevation gameplay, generator, map-mode framework, shader, final art, biome, hydrology, navigation, or Faz 2A system was added.
- Local parser/import, runtime smoke, and all five headless suites passed.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 1E scope.
- Commit: `e1e19f8ae64870a6330a3e508b9d48537b1e4f9e` (`feat: visualize secondary world layer`).

## 2026-09-14 — Faz 2A: Deterministic World Initialization & Generation Boundary

- Added concise persistent planning guardrails that keep future work aligned with Semarel's long-term living sandbox goal without replacing implementation rules in `AGENTS.md`.
- Added a scene-tree-independent `WorldGenerator` that writes initial terrain and prototype elevation through `WorldGrid` using an explicit integer seed, generator version `1`, a fresh local RNG per call, and world-coordinate-derived values.
- Kept generation as a temporary producer: it neither owns the target world nor commits revisions, renders, stores runtime state, or acts as simulation.
- Added data-only terrain, elevation, and combined fingerprints evaluated in deterministic logical coordinate order.
- Proved same-seed stability, different-seed variation, global RNG isolation, repeated-instance stability, valid values, bounds, 65×65 partial edges, chunk-size independence, lack of chunk seam dependency, and one-batch initialization semantics in a dedicated 53-assertion suite.
- Switched the debug main preview from `WorldPreviewFixture` to fixed seed `12345` generation while retaining the fixture for focused presentation tests and displaying seed/version as development information.
- Preserved the five existing suites (308 assertions); parser/import, runtime smoke, and all six headless suites pass through the single validation command.
- Recorded a non-gating 256×256 generation sanity baseline in `docs/PERFORMANCE.md`; no CI timing threshold, optimization, threading, or production generator was added.
- No biome, river, climate, resource, civilization, runtime simulation, world-creation UX, or save compatibility system was implemented.
- Local validation and interactive preview inspection passed; post-push GitHub Actions status is reported after the workflow is observed.
- Unresolved issues: none in the implemented Faz 2A scope.
- Commit: `feat: establish deterministic world generation boundary` (exact hash will be backfilled during the next context-maintenance task).
