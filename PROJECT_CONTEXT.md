# Semarel Project Context

## Current state

- Purpose: an original large-scale 2D pixel-art god/sandbox world simulation named **Semarel**.
- Repository: `https://github.com/GandalfTheGrayy/Semarel`.
- Engine: Godot Standard 4.7.2 stable.
- Language: GDScript.
- **Faz 1A – Authoritative World Data Foundation** is complete, pushed, and validated on `main`.
- **Faz 1B – Terrain Visualization & World Inspection** is complete, pushed, and validated on `main`.
- **Faz 1C – Generic World Change Propagation & Incremental Refresh** is complete, pushed, and validated on `main`.
- **Faz 1D – Second Logical World Layer Extensibility Probe** is complete, pushed, and validated on `main`.
- Faz 1A–1E foundation series is complete: authoritative data, chunking, multiple logical layers, committed change propagation, and independent presentation consumers are proven by code and tests.
- **Faz 2A – Deterministic World Initialization & Generation Boundary** is complete, pushed, and validated on `main`.
- **Faz 2B – First Coherent Seeded World Prototype** is complete, pushed, and validated on `main` at `58b4de7557713ab629959e5e75f9139d4c1f11be`.
- **Faz 3A – Simulation Clock & Minimal Entity Foundation** is complete, pushed, and validated on `main` at `0bae4f5e314ace45f9354d38f1a035be292a3e5a`.
- Current completed phase: **Faz 3B.1 – Movement Hot-Path Diagnosis & Bounded Correction**.
- Next proposed phase: **Faz 3C – First Agent State & Lifecycle Slice**; this remains subject to repository and product-direction review.

## Implemented systems

- `WorldGrid` owns the bounded logical world, chunk collection, coordinate conversion, terrain/elevation access, category-specific pending chunk invalidations, and committed revision.
- `WorldChunkData` is a scene-tree-independent `RefCounted` data object with separate flat `PackedByteArray` terrain and prototype elevation storage.
- Logical world positions use `Vector2i`; pixels, sprites, textures, and camera state are not part of world data.
- The current prototype defaults are 64×64 cells per chunk and a 256×256-cell test world. Neither is a final design decision.
- Placeholder terrain IDs are `WATER`, `LAND`, `SAND`, and `ROCK`; they validate the storage contract and are not the final terrain design.
- Headless world-data tests run through `tools/validate.ps1` locally and in GitHub Actions.
- A small, non-gating data sanity benchmark exists at `benchmarks/world_data_sanity.gd`.
- `TerrainPalette` maps prototype terrain IDs to debug-only colors and names without adding visual data to `TerrainTypes`.
- `TerrainRasterizer` converts copied chunk terrain snapshots into one-texel-per-cell `Image` data.
- `TerrainRenderer` creates one `Sprite2D`/`ImageTexture` visual per logical chunk, uses 2× nearest-neighbor display scaling, and supports full rebuild plus selected-chunk refresh.
- `ElevationRasterizer` converts copied prototype elevation snapshots to deterministic grayscale debug images.
- `ElevationOverlayRenderer` is a separate, toggleable, semi-transparent presentation consumer with one derived visual per chunk.
- `WorldPresentationConfig` owns the shared prototype 2× presentation scale and debug overlay opacity without affecting world data.
- `WorldInspector` reports read-only world, chunk, local, terrain, and unitless prototype elevation information under the mouse.
- `WorldPreviewFixture` creates a deterministic debug island and simple elevation gradient solely for presentation verification; it is not production generation.
- `WorldGenerator` is a scene-tree-independent initial-data producer with an explicit integer seed and version `2`; it does not own `WorldGrid`, commit revisions, render, or run as simulation.
- Generator v2 samples one deterministic smooth FBM height field in logical world coordinates, applies a prototype radial edge falloff, quantizes relative height to the existing elevation byte, and classifies prototype terrain from that same value.
- `WorldFingerprint` computes deterministic terrain, elevation, and combined data-only checksums in logical world-coordinate order.
- The main preview now generates its initial authoritative values with fixed debug seed `12345`, commits one initialization batch, and displays the seed/version for inspection.
- The 256×256 preview produces 16 chunk visuals, not 65,536 cell Nodes.
- Prototype elevation is a second independent byte-sized scalar layer with default value `0`; its range and physical/gameplay meaning are not final design decisions.
- `WorldChangeSet` represents one committed world-change batch with a revision and separate, deterministically ordered terrain/elevation chunk invalidations.
- `WorldGrid.commit_changes()` separates pending mutations from stable multi-consumer snapshots and advances revision only for non-empty batches.
- The SPACE-key `DebugWorldChangeProbe` path changes four cells across four chunk boundaries and routes one committed change set to the renderer and debug UI.
- `SimulationClock` is a scene-tree-independent fixed-step accumulator. Its prototype 10 Hz tick index advances independently from render frames and `WorldGrid` revisions.
- `EntityStore` owns minimal entity identity and logical cell position in dense packed columns: stable IDs in `PackedInt64Array`, x/y in separate `PackedInt32Array` values, plus one ID-to-dense-index lookup.
- Entity IDs begin at 1, increase monotonically, are never reused, and remain distinct from swap-remove dense indices.
- `DebugEntityRenderer` draws copied entity positions from one `Node2D`; the 32-entity preview creates no per-entity Nodes and refreshes at most once after all due ticks in a render frame.
- A non-gating 10,000-entity create/read-update/remove sanity workload exists at `benchmarks/entity_store_sanity.gd`.
- `PrototypeEntityMovement` is a stateless, scene-tree-independent fixed-tick behavior that chooses cardinal directions deterministically from stable entity ID plus tick index.
- The movement prototype reads `WorldGrid`, writes authoritative positions through `EntityStore`, rejects out-of-bounds/WATER destinations, and reports only a moved-entity count.
- A separate non-gating 10,000-entity/100-tick movement sanity workload exists at `benchmarks/entity_movement_sanity.gd`.
- A development-only, non-gating component benchmark at `benchmarks/entity_movement_profile.gd` compares dense ID/hash work, position reads, safe terrain reads, position writes, and full movement at the same 10,000-entity/100-tick scale.

## Current architecture

- The authoritative state is plain data and does not depend on Nodes, scenes, TileMap, sprites, textures, or rendering.
- External systems access terrain and elevation through `WorldGrid`, rather than depending on chunk array layout.
- `WorldGrid` converts world coordinates to chunk/local coordinates once and delegates both compact storages to `WorldChunkData`.
- Successful terrain changes add one pending chunk invalidation; repeated writes in the same chunk are deduplicated and same-value writes add nothing.
- Elevation changes use a separate pending category with the same deduplication and same-value behavior; neither layer marks the other category.
- Out-of-world reads return `TerrainTypes.INVALID`; out-of-world or invalid-ID writes return `false` and do not mutate or create pending changes.
- Out-of-world elevation reads return `WorldChunkData.INVALID_ELEVATION`; invalid elevation writes return `false` without changing either layer.
- The implemented terrain/elevation split proves that another packed logical layer can share chunk coordinates without coupling storage or change categories.
- Renderer input is obtained through clipped chunk rectangles and copied terrain snapshots; presentation never receives mutable authoritative arrays.
- Presentation images, textures, and sprites can be destroyed and rebuilt completely from `WorldGrid`.
- `commit_changes()` returns an immutable-by-contract `WorldChangeSet`; chunk getters return copies and chunks are sorted by y then x.
- Consumers never own or clear pending state. `TerrainRenderer.apply_world_changes()` reads a change set without modifying it, the world revision, or authoritative terrain.
- `TerrainRenderer` reads only terrain invalidations; an elevation-only commit produces no terrain refresh or visual change.
- `ElevationOverlayRenderer` reads only elevation invalidations; terrain-only commits produce no overlay texture refresh.
- The same immutable mixed `WorldChangeSet` can be observed independently by both renderers and debug UI.
- All derived elevation images, textures, and sprites can be destroyed and rebuilt from copied `WorldGrid` data.
- Old change sets remain stable after later world mutations and commits.
- Generation uses a fresh local `RandomNumberGenerator` per call to seed a local smooth-noise field, then samples world coordinates; global RNG activity and chunk partitioning do not affect logical output.
- Terrain and elevation are related through the generator-v2 prototype height field. This relationship belongs to the replaceable v2 algorithm and is not a global `WorldGrid` invariant.
- Generation writes through the public `WorldGrid` API and leaves pending changes for the owner/orchestrator to commit once. Runtime authoritative ownership remains exclusively with `WorldGrid`.
- Generation is new-world initialization, not ongoing climate, erosion, ecosystem, or other runtime simulation.
- Environment state, entity state, simulation time, and presentation have separate owners: `WorldGrid`, `EntityStore`, `SimulationClock`, and renderer Nodes respectively.
- `EntityStore` validates logical world bounds but deliberately knows nothing about terrain, rendering, behavior, types, health, AI, or navigation.
- Entity removal uses swap-remove and repairs the moved stable-ID mapping in constant time; stale IDs are rejected safely.
- `SimulationClock.add_time()` rejects negative deltas, accumulates non-negative render delta, and exposes every due fixed tick through `consume_tick()`. Large-frame catch-up currently processes all due ticks; a production overload cap remains undecided.
- Stable entity IDs are identity; dense indices are ephemeral storage positions that may change after swap-remove and must not be retained across lifecycle changes.
- Movement iterates the dense store without full-store snapshots and performs no create/remove, so the dense layout stays fixed during each pass.
- Direction decisions depend on stable ID and tick rather than dense order. Global RNG activity and render-frame schedule do not affect final positions for the same tick sequence.
- The main preview processes every due movement tick, then refreshes entity presentation once only if at least one entity moved.
- Entity movement does not mutate `WorldGrid` or advance its revision. It has no entity revision or change-set framework because no second entity-state consumer requires one yet.
- Faz 3B.1 measured safe `WorldGrid.get_terrain()` access as the dominant isolated movement component. Its bounded correction computes the chunk coordinate once and derives the local coordinate without exposing unchecked storage or changing safe invalid/outside behavior.
- High-frequency systems avoid repeated full-store snapshots and redundant coordinate transforms while retaining authoritative ownership and encapsulation. No ECS, threading, or spatial index was introduced.

## Confirmed decisions

- Godot 4.x Standard with GDScript and a 2D workflow.
- Nearest-neighbor canvas texture filtering and integer-friendly stretch scaling.
- Authoritative world state and visual representation are separate concerns.
- Terrain is the first logical world layer, not the complete world model.
- Cell data uses compact storage; there is no per-cell Node, Object, Dictionary, or Resource.
- Prototype elevation is an architecture probe, not a final 8-bit elevation, sea-level, slope, mountain, hydrology, or gameplay system.
- Grayscale elevation and 58% overlay opacity are debug presentation choices, not final art direction or a production map mode.
- Generator v2, seed `12345`, noise parameters, edge falloff, and terrain thresholds are prototype choices, not final world topology, sea level, elevation model, geology, hydrology, or game-design rules.
- World-change revisions identify committed non-empty batches only; they are not simulation ticks, save versions, or network sequence numbers.
- The current 10 Hz clock and logical-cell entity positions are engineering prototype contracts, not final simulation-rate or movement-scale decisions.
- `EntityStore` is a minimal data owner, not an ECS framework or final entity model.
- Cardinal one-cell movement, prototype WATER blocking, lack of occupancy, and allowing multiple entities in one cell are temporary Faz 3B contracts, not universal species or final movement rules.
- Semarel may take high-level inspiration from emergent sandbox simulations, but its systems, mechanics, identity, and visual language must be original.

## Open decisions

Final chunk size, logical world size, terrain type count, terrain art scale, biome architecture, elevation representation/precision/meaning, production generation algorithm and layer relationships, simulation tick rate/catch-up policy, final entity schema, sub-cell movement/speed, terrain costs, swimming/flying, occupancy/collision, climate simulation, fluid simulation, navigation, save format, and threading model remain intentionally undecided.

## Verified development tools

Godot, Git, Git LFS, Python, pip, ImageMagick, FFmpeg, ffprobe, SoX, Inkscape CLI, ripgrep, jq, 7-Zip CLI, and hyperfine are available. Exact versions and paths are in `docs/DEVELOPMENT_SETUP.md` and can be rechecked with `tools/toolcheck.ps1`.

## Known problems and performance data

- Known project problems: safe world terrain access remains the largest isolated component in the synthetic Faz 3B.1 movement diagnosis even after the bounded coordinate-transform correction; more invasive optimization is deferred until representative simulation evidence exists.
- Data-only world access, generation, entity-store, and minimal movement sanity/diagnostic measurements are recorded in `docs/PERFORMANCE.md`; none is a performance target, supported-NPC claim, production guarantee, or CI threshold.
- Production-quality procedural generation, AI, pathfinding, occupancy, animation, agent lifecycle/state, biomes, climate, hydrology, navigation, save/load, elevation gameplay, and further logical layers remain unimplemented by design.

## Repository rules

- `docs/PLANNING_GUARDRAILS.md` is the persistent project-direction reference used alongside repository evidence when planning future phases; it does not replace `AGENTS.md`.
- Treat current code, documentation, and Git history as the durable source of truth.
- Preserve unrelated user work and inspect existing behavior before changing it.
- Keep tasks scoped, test meaningful changes, update context/log/next documents, review diffs, commit, and push.
- Do not silently promote proposals to confirmed features.
- Do not apply Git LFS broadly to all PNG files; add targeted patterns only for genuinely large binary sources.
