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
- Local validation and interactive preview inspection passed.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 2A scope.
- Commit: `a455e472f1943c1b7dfe5a8fb64c5c1317ef2ab7` (`feat: establish deterministic world generation boundary`).

## 2026-09-15 — Faz 2B: First Coherent Seeded World Prototype

- Replaced generator-v1 block regions and per-cell elevation hash output with generator version `2`, using one local-seed-derived `FastNoiseLite` smooth FBM field plus a prototype radial edge falloff.
- Quantized the shared relative-height field to the existing 0–255 prototype elevation storage and classified WATER, SAND, LAND, and ROCK from explicit v2-only thresholds.
- Preserved the Faz 2A boundary: generation remains data-only, world-coordinate-based, free of retained run state, independent from global RNG and chunk partitioning, and leaves authoritative ownership/commit timing to `WorldGrid`.
- Added v2 golden regression fingerprints for seed `12345`, world 64×64, and chunk size 16: terrain `823958333`, elevation `1193244069`, combined `3136019`.
- Expanded generation coverage from 53 to 68 assertions with coherent-neighbor behavior, broad height variation, edge water, exact v2 terrain/elevation relation, all-category presence, removal of the old 12×12 region dependency, and chunk-size 8/16/64 equivalence.
- Default 256×256 seed `12345` distribution was WATER 46.053%, SAND 3.339%, LAND 41.348%, and ROCK 9.261%; these are sanity observations, not design targets.
- Interactive OpenGL inspection confirmed a continuous island-scale landmass, readable shoreline, elevated rock regions, smooth correlated elevation overlay, aligned presentation, valid inspector data, and no visible chunk seams.
- Updated the non-gating generation benchmark for v2; no biome, climate, river, lake, erosion, resource, civilization, threading, or production-generation framework was added.
- Local validation and all six suites passed; GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 2B scope.
- Commit: `58b4de7557713ab629959e5e75f9139d4c1f11be` (`feat: generate first coherent seeded world`).

## 2026-09-15 — Faz 3A: Simulation Clock & Minimal Entity Foundation

- Added a scene-tree-independent `SimulationClock` with a centralized prototype 10 Hz fixed interval, safe negative-delta rejection, sub-tick accumulation, multi-tick catch-up, and a tick index independent from world revision.
- Added a scene-tree-independent `EntityStore` with monotonic stable IDs, dense packed ID/x/y columns, one ID-to-dense-index map, bounded logical positions, copied snapshots, safe stale-ID behavior, and swap-remove mapping repair.
- Kept the minimal entity schema to identity plus position; no per-entity Node/Object/Dictionary/Resource, ECS framework, entity type, health, behavior, AI, movement, pathfinding, or spatial index was added.
- Added one `DebugEntityRenderer` Node that draws a copied snapshot of 32 deterministic non-water debug positions and refreshes explicitly rather than on every render frame.
- Wired render delta into the fixed clock and exposed simulation tick/entity count beside the existing world revision, seed, generator, SPACE, and elevation-overlay diagnostics; no per-entity tick loop was added.
- Added three focused headless suites covering fixed-step schedule equivalence, world-revision independence, entity lifecycle/identity/bounds/swap-remove/snapshots, and 100-entity single-node rendering.
- Added a non-gating 10,000-entity lifecycle sanity benchmark; no performance threshold or optimization claim was introduced.
- Interactive OpenGL inspection confirmed 32 visible markers from one renderer with zero child Nodes, simulation tick progression while world revision stayed fixed, readable diagnostics/inspector data, and working elevation-overlay plus four-chunk SPACE paths.
- Preserved all six existing suites and the authoritative-world, generation, change-set, and presentation boundaries.
- GitHub Actions validation passed for the implementation commit.
- Unresolved issues: none in the implemented Faz 3A scope.
- Commit: `0bae4f5e314ace45f9354d38f1a035be292a3e5a` (`feat: add simulation clock and entity foundation`).

## 2026-09-15 — Faz 3B: Minimal Deterministic Entity Movement

- Added controlled dense-index reads/writes to `EntityStore` for hot-loop iteration without full ID/position snapshots; invalid indices fail safely and stable IDs remain the only persistent identity.
- Added stateless, data-only `PrototypeEntityMovement`, whose stable-ID-plus-tick integer hash selects a cardinal starting direction before testing all four neighbors deterministically.
- Kept prototype passability local to movement: valid non-WATER destinations pass, while WATER/out-of-bounds destinations are rejected; no occupancy, collision, pathfinding, target, AI, or movement framework was introduced.
- Integrated movement after each consumed fixed tick and coalesced presentation to at most one `DebugEntityRenderer` snapshot refresh after all due ticks in the render frame.
- Preserved entity count/IDs and `WorldGrid` revision; movement creates/removes no entities, writes only `EntityStore` positions, and emits only a moved-entity count.
- Expanded `EntityStore` coverage to 58 assertions and added a 210-assertion movement suite covering determinism, global-RNG isolation, first-tick semantics, 60/30/10-frame schedule equivalence, explicit LAND/SAND/ROCK/WATER behavior, bounds/one-cell constraints, dense-order independence, snapshot refresh, and five-tick catch-up coalescing.
- Preserved the nine Faz 3A suites; all ten suites total 685 assertions through the standard validation command.
- Measured separate non-gating storage and minimal-movement sanity workloads; the movement workload contains no AI, pathfinding, needs, combat, social simulation, spatial index, or rendering cost.
- Interactive OpenGL inspection confirmed all 32 debug entities changed logical position by tick 9 without entering WATER or leaving world bounds, movement diagnostics advanced while normal movement left world revision unchanged, and one renderer retained 32 markers with zero child Nodes. The existing elevation overlay, inspector, and SPACE world-change path also remained functional.
- Unresolved issues: none in the implemented Faz 3B scope.
- GitHub Actions validation passed for the implementation commit (Validate run `34905572036`).
- Commit: `a26f885f89dd5e8eaf8b2546ceb5c34ed97fb905` (`feat: add deterministic entity movement`).

## 2026-09-15 — Faz 3B.1: Movement Hot-Path Diagnosis & Bounded Correction

- Repeated the unchanged 10,000-entity/100-tick/all-LAND movement workload five times after one excluded pre-sample: the before median was 5,711.539 ms with a 5,645.543–5,964.710 ms range. The excluded 7,191.933 ms run followed discarded non-waiting process launches and may have included host contention.
- Added the development-only, non-gating `entity_movement_profile.gd` benchmark with comparable one-million-operation dense stable-ID/hash, dense position-read, safe terrain-read, position-write, and full-movement workloads.
- The diagnostic median identified safe `WorldGrid.get_terrain()` calls as the dominant isolated component: 2,407.525 ms, versus 639.746 ms for ID/hash, 486.305 ms for position reads, and 788.829 ms for position writes.
- Made one bounded production correction: `WorldGrid.get_terrain()` now computes its chunk coordinate once and derives the local coordinate from it, while retaining world bounds checks, chunk encapsulation, and `WorldChunkData` local validation.
- Added representative terrain-read regressions across chunk sizes 3, 8, and 64, including origin, boundary-minus-one, boundary, partial edge, negative, and outside coordinates.
- Five equivalent after samples produced a 5,239.395 ms median and 5,191.591–5,370.259 ms range: 472.144 ms (8.27%) below the before median. Diagnostic terrain-read median fell to 1,980.166 ms (17.75%).
- The before/after final movement checksum remained `1559308248`, all 1,000,000 moves completed, and the world revision remained zero. No movement behavior, tick rate, entity count, ECS, threading, spatial index, unsafe storage API, or gameplay state was added.
- Timing remains diagnostic only: it is not a supported-NPC claim, production tick budget, or CI threshold. The safe terrain-read layer remains the largest isolated measured component and should be reassessed only with future representative simulation evidence.
- Final standard validation passed all ten suites with 715 assertions. The entity-store sanity, movement sanity, and movement-profile commands also completed successfully; the final movement run retained the expected checksum and revision.
- GitHub Actions validation passed for the implementation commit (Validate run `34906737333`).
- Commit: `10f90a059f93d054e0e896977518822bb8b331bf` (`perf: reduce entity movement hot-path overhead`).

## 2026-09-15 — Faz 3C: Heterogeneous Entity State Boundary & First Living-State Slice

- Added `docs/FUTURE_SYSTEM_CONSTRAINTS.md` as a broad architecture-capability horizon covering heterogeneous creatures and objects, lifecycle and health, movement modes, settlements and states, economy, inventory, combat, environment, supernatural systems, social/history inspection, saves, scale, modding, and possible networking. It explicitly defines no mechanics, implementation order, schema, UI, or balance.
- Added a permanent planning guardrail: before opening a new gameplay/content domain, stop and ask the user which requirements its infrastructure must support. Technical corrections, tests, performance work, and continuation of an already approved narrow slice remain exempt.
- Kept `EntityStore` generic and introduced a separate `RefCounted` `LivingStateStore` bound to it. The optional store packs stable entity IDs and `birth_tick` values in `PackedInt64Array` columns, validates core existence, uses swap-remove, and derives age on demand without per-tick mutation.
- Established ownership explicitly: optional living-state removal preserves core identity/position; the orchestration owner cleans optional rows before core removal. No event bus, lifecycle coordinator, registry, inheritance model, or ECS was added.
- Changed prototype movement to iterate living dense membership while resolving authoritative positions through `EntityStore`. Core entities without living state do not move; stable-ID-plus-tick decisions remain independent from dense order. Living membership is not a promise that every future living category walks.
- Attached living state with `birth_tick = 0` to the existing 32 debug preview entities and exposed separate core/living counts without inventing domain entities.
- Added a 67-assertion living-state suite and expanded movement to 224 assertions, including three-core/two-living heterogeneity, optional-state ownership, swap-remove, derived-age immutability, living-only movement, and living-dense-order independence.
- The standard validation command passed all eleven suites with 796 assertions, including the bounded runtime smoke test reporting 32 core and 32 living preview entities.
- Updated the 10,000-entity/100-tick all-LAND benchmark so all core entities have living state. The final run measured 5,719.269 ms total (57.193 ms/tick), 1,000,000 moves, checksum `1559308248`, and world revision zero. This is 9.16% above the earlier corrected median, not a catastrophic 2×/3× regression, and creates no supported-population or optimization claim.
- The requested Windows interactive capture was attempted against the detected `Semarel (DEBUG)` window, but the capture helper failed twice with `SetIsBorderRequired failed: No such interface supported (0x80004002)`. No unreliable UI input was sent. The headless main-scene smoke and focused suites covered 32 core/32 living startup, deterministic movement, tick/revision separation, overlay/change paths, and the single-renderer/no-child-entity-node contracts.
- Updated architecture, design, context, performance, next-step, and task-history documentation. Work stops at **Planning Checkpoint – Domain-Specific Entity Systems**; the next domain requires user consultation.
- Commit subject: `feat: establish optional living entity state` (exact hash will be backfilled by the next context-maintenance task).
