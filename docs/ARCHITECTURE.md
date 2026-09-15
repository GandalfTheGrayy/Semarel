# Architecture

## Authoritative world data

The logical world is authoritative data. Rendering is a consumer of that data and must not become its source of truth.

```text
Authoritative World State
        WorldGrid
            ↓ owns chunks, bounds, coordinate conversion, pending categories
    WorldChunkData
            ├── PackedByteArray terrain
            └── PackedByteArray prototype elevation

Authoritative World State ≠ Rendering
```

`WorldGrid` and `WorldChunkData` extend `RefCounted`, not `Node`. They can therefore be created, queried, mutated, and tested without a scene tree, renderer, TileMap, sprite, texture, or camera.

## WorldGrid responsibilities

- Own the bounded logical world and its chunk collection.
- Keep the prototype chunk size in the single `DEFAULT_CHUNK_SIZE` constant (currently 64).
- Keep the prototype world size in `DEFAULT_WORLD_SIZE` (currently 256×256 cells).
- Convert `Vector2i` world coordinates to chunk and local coordinates in one place.
- Expose terrain and prototype elevation reads/writes without exposing chunk array indexing to consumers.
- Track pending terrain and elevation chunks as separate deduplicated sets until commit.

Coordinate helpers use floor-based chunk coordinates and normalized local coordinates for any integer input. Layer access is stricter: positions must be in `[0, world_size)`. An out-of-world terrain read returns `TerrainTypes.INVALID`; an out-of-world elevation read returns `WorldChunkData.INVALID_ELEVATION`. Invalid writes return `false`, change nothing, and create no pending invalidation.

World dimensions do not have to be exact multiples of the chunk size. Edge chunks retain the standard storage size while `WorldGrid` enforces the true world bounds.

Chunk-facing reads reuse `is_valid_chunk_position()`, `chunk_to_world_origin()`, and `get_chunk_world_rect()`. Both `get_chunk_terrain_copy()` and `get_chunk_elevation_copy()` return copies, never mutable references to authoritative arrays. `get_chunk_world_rect()` clips right and bottom edge chunks to the actual world dimensions so padded storage cells remain inaccessible through world coordinates.

## WorldChunkData responsibilities

- Own one chunk's terrain layer and one prototype elevation layer as separate flat `PackedByteArray` values.
- Validate local coordinates.
- Read, write, fill, and copy each layer independently.
- Centralize flat indexing as `index = y * chunk_size + x`.

The storage creates no per-cell Node, Object, Dictionary, or Resource. Terrain values are compact byte-sized IDs. `WATER`, `LAND`, `SAND`, and `ROCK` are prototype values, not final game-design commitments. Elevation is also one byte per cell in this probe, with default `0`; the range, precision, physical meaning, and gameplay use remain undecided.

## World change propagation

```text
AUTHORITATIVE MUTATION

WorldGrid.set_terrain(...) / set_elevation(...)
        ↓
pending terrain chunks / pending elevation chunks
        ↓
WorldGrid.commit_changes()
        ↓
WorldChangeSet revision N
        ├── terrain chunks
        └── elevation chunks
        ↓
        ├── TerrainRenderer
        ├── future Navigation
        ├── future Save/Streaming
        └── future World Systems
```

Each layer records its own pending chunk only when its stored value changes. A chunk changed once or hundreds of times appears once in that category. Terrain never marks elevation pending and elevation never marks terrain pending. `commit_changes()` sorts both categories by y then x, clears both pending sets, and returns one stable `WorldChangeSet`. A terrain-only, elevation-only, or mixed non-empty commit increments the single world revision once; an empty commit retains the current revision.

`WorldChangeSet` is immutable by contract. It independently copies, deduplicates, and sorts terrain/elevation constructor input; both category getters return new arrays on every call. `is_empty()` is true only when both categories are empty. Later mutations and commits cannot change older snapshots. Consumers do not own or consume authoritative pending state.

`TerrainRenderer.apply_world_changes()` reads terrain chunk invalidations and refreshes only those visuals. The same change set remains available to any number of consumers. The revision identifies committed world-change batches; it is not a simulation tick, save version, or network sequence.

`ElevationOverlayRenderer.apply_world_changes()` independently reads elevation chunk invalidations. Terrain-only batches trigger no elevation refresh, elevation-only batches trigger no terrain refresh, and mixed batches can be passed unchanged to both renderers and debug UI.

`WorldChangeSet` is an invalidation/change-summary mechanism, not a gameplay event bus and not a full cell-by-cell diff. It stores no old/new values, timestamps, actors, reasons, or undo data. Terrain and prototype elevation are its only current categories; future authoritative layers may add their own chunk invalidations when they actually exist.

## Future logical layers

Faz 1D provides the first code-level proof that terrain is not the entire world model:

```text
WorldGrid
   ├── terrain
   └── prototype elevation

WorldChangeSet revision N
   ├── terrain chunks
   └── elevation chunks
```

Elevation is deliberately explicit code, not a generic layer registry. If many independent layers later accumulate directly in `WorldChunkData` and make the class unwieldy, chunk-owned component/layer storage will be reconsidered then. Moisture, climate, resources, ownership, environmental state, and other candidate layers remain unimplemented.

Likewise, final chunk size, world size, terrain count, save format, threading model, navigation representation, and generation strategy remain open decisions.

## Presentation flow

```text
AUTHORITATIVE

WorldGrid
   ├── terrain PackedByteArray
   └── prototype elevation PackedByteArray


PRESENTATION

copied terrain snapshot                 copied elevation snapshot
          ↓                                       ↓
TerrainRasterizer                     ElevationRasterizer
          ↓                                       ↓
TerrainRenderer                       ElevationOverlayRenderer
          ↓                                       ↓
ImageTexture / Sprite2D               ImageTexture / Sprite2D
one visual per chunk                  one visual per chunk


INCREMENTAL PRESENTATION

WorldChangeSet
   ├── terrain chunks   → TerrainRenderer
   └── elevation chunks → ElevationOverlayRenderer
```

`TerrainPalette` owns debug terrain colors; `ElevationRasterizer` maps prototype bytes directly to deterministic grayscale. Neither color mapping belongs to authoritative data. `WorldPresentationConfig` holds the shared prototype 2× scale and 58% elevation overlay opacity. These are debug settings, not final art decisions.

Both renderers support `rebuild_all()` and category-specific `apply_world_changes(change_set)`. Same-sized textures use `ImageTexture.update()`; only size changes allocate a new texture. Their small CPU `Image` caches are deterministic, testable derived data and are never authoritative.

Presentation state can be destroyed and rebuilt from copied `WorldGrid` snapshots. Deleting every terrain/elevation `Image`, `ImageTexture`, and `Sprite2D` does not affect either authoritative layer.

`TerrainRenderer` does not know about elevation storage. `ElevationOverlayRenderer` does not read terrain storage. The latter sits above terrain through presentation-only z-ordering, starts hidden, and can be toggled with the debug `E` input. Renderer revision fields only record observation; `WorldGrid` remains revision owner.

`WorldPreviewFixture` is an explicit deterministic debug fixture, not a procedural world generator. It now writes a simple x/y elevation gradient beside the debug island, creating one mixed initial commit. `WorldInspector` maps display coordinates through the shared scale and reads both terrain and unitless elevation without mutating them.

The SPACE-key debug change probe is development validation, not runtime terrain-editing gameplay. Its four fixed cells straddle x/y chunk boundaries so a single batch proves targeted refresh across four chunks.

Some implementation repetition is now visible between the two explicit chunk renderers. A generic renderer abstraction will be reconsidered only when a third real presentation layer exists or this repetition creates a demonstrated maintenance problem. Faz 1E does not introduce a renderer registry, layer mode, or map-mode framework.

## New-world generation boundary

```text
NEW WORLD CREATION

world size + chunk size + explicit seed
        ↓
WorldGenerator version 2
        ↓
deterministic smooth FBM world field
        ↓
prototype relative height + edge falloff
        ├── elevation byte
        └── terrain classification
        ↓ writes initial logical values
WorldGrid
        ↓ owner/orchestrator calls commit_changes()
Initial WorldChangeSet
        ↓
Presentation / future consumers
```

`WorldGenerator` is a producer; `WorldGrid` remains the authoritative runtime owner. The generator receives a target grid for one call, writes only through its public coordinate APIs, retains no world reference or mutable run state, and does not commit, render, or access the scene tree. The caller decides when initialization is complete and commits the accumulated terrain/elevation invalidations as one batch.

Generation uses an explicit integer seed and a fresh local `RandomNumberGenerator` to derive the seed of one local `FastNoiseLite` simplex-smooth FBM field. The field is sampled only in logical world coordinates. A smooth radial edge falloff lowers the prototype preview boundary, and the resulting relative height is quantized into the existing elevation byte. Prototype terrain is classified from that same byte: low values are water, a narrow threshold band is sand, the middle is land, and high values are rock. Global RNG use elsewhere cannot perturb output. The algorithm never reads chunk coordinates, so changing the partition between chunk sizes 8, 16, and 64 preserves identical logical values and creates no generation seams.

Generator v1 was the deterministic-boundary engineering probe. `WorldGenerator.GENERATOR_VERSION = 2` identifies the first coherent seeded-world prototype. The version is a small regression identifier, not a save compatibility framework. A 64×64/seed-12345 golden fixture protects v2's terrain, elevation, and combined fingerprints; deliberate algorithm changes require a version bump and newly measured golden values.

The shared-height relation is specific to generator v2. It is not a `WorldGrid` invariant or a permanent rule that terrain must derive only from elevation. Future climate, biome, geology, moisture, resources, or other generation stages may change that relationship when their requirements exist. The fixed preview seed, noise frequencies, falloff, 0–255 quantization, and classification thresholds remain replaceable prototype decisions.

`WorldFingerprint` reads authoritative terrain/elevation in stable row-major logical order and produces separate and combined non-cryptographic checksums. It exists for reproducibility tests and diagnostics, contains no presentation data, and does not make the generated algorithm final.

`WorldPreviewFixture` remains a presentation-test fixture for known pixel expectations. It is distinct from `WorldGenerator`, which initializes the main preview and produces the first spatially coherent debug world. Generation means new-world creation; it is not runtime simulation and does not stand in for future climate, erosion, ecosystems, resources, or other ongoing systems. Generator v2 is not the final procedural generator, biome model, elevation model, geology system, or hydrology system.

## Simulation time and heterogeneous entity state

The Faz 1-3 foundation period is complete for current gameplay work. It established authoritative mutable world data, deterministic generation, a fixed simulation clock, generic stable-ID entity storage, composable optional state, an identity-preserving lifecycle transition, stable cross-entity references, and repeatable validation/measurement. New infrastructure from Faz 4 onward should normally answer an actual gameplay or simulation requirement. `NEXT.md` remains a planning proposal rather than an automatic implementation command; the former Faz 3F data-driven definition proposal is deferred until multiple real content consumers justify it.

```text
FRAME TIME                         AUTHORITATIVE OWNERS

render delta                       WorldGrid
    ↓                              └── environment layers + world revision
SimulationClock (10 Hz prototype)
    ↓ zero or more fixed ticks     EntityStore
simulation tick index              └── stable IDs + logical cell positions

WorldGrid / EntityStore copied snapshots
    ↓
Presentation consumers
```

`SimulationClock` is a data-only fixed-step accumulator. It accepts non-negative elapsed time, makes every complete 0.1-second prototype interval available for explicit consumption, and increments its tick index once per consumed interval. Zero time produces no tick and negative time is rejected without changing state. A large delta currently exposes all due ticks; overload caps, pausing, time scale, scheduling, and the final tick rate remain future decisions. A simulation tick is independent from render FPS and is not a `WorldGrid` revision.

`EntityStore` is the authoritative owner of the current minimal entity state. It stores stable monotonic IDs in a `PackedInt64Array` and logical x/y cell coordinates in separate `PackedInt32Array` columns. One `Dictionary` maps stable IDs to replaceable dense indices. Removal swaps the last dense row into a removed slot, repairs that stable ID's lookup, and shrinks the packed columns. IDs are never reused, and stale IDs fail safely.

Logical positions are bounded by the supplied world size, but `EntityStore` has no terrain, rendering, simulation-clock, generation, behavior, or scene-tree dependency. Its copied ID/position snapshots prevent presentation consumers from mutating authoritative state. Identity plus position is only the first measured schema; types, health, ownership, behavior, and other components will be added only when real requirements exist.

`EntityStore` is not an ECS framework. Faz 3A deliberately adds no registry, query system, component interface, inheritance tree, system scheduler, or generic entity manager. Dense packed columns and stable lookup solve only the current lifecycle requirement.

`LivingStateStore` is a separate optional-state owner bound to one `EntityStore`. It stores only the stable entity ID and `birth_tick` in packed `PackedInt64Array` columns, with a dictionary from stable ID to ephemeral dense index. A generic entity without a living-state row remains a valid non-living entity. An entity ID is owned by `EntityStore`; optional stores never allocate, recycle, or replace identity.

Age is derived as `current_tick - birth_tick` on demand. It is not stored and is not incremented every simulation tick. Invalid membership, a negative birth tick, or a current tick before birth returns the documented sentinel. Simulation ticks remain independent from world revisions.

```text
EntityStore
  all generic entities: stable ID + logical position

Optional state stores
  LivingStateStore: living members only + birth_tick
  RemainsStateStore: post-living prototype members only + death_tick

EntityStore entity
  may have LivingState
  may later have other domain state
  does not imply NPC, agent, or living creature
```

Removing living state does not remove the core entity. The orchestration owner must remove optional state before removing the core entity when destroying an entity. Faz 3C deliberately adds no event bus, lifecycle coordinator, component registry, or ECS. Future building, inventory, combat, or other domain data may use separate optional owners if their actual requirements justify that structure.

## Stable prototype lifecycle transition

`RemainsStateStore` is another optional owner bound to one `EntityStore`. It uses dense `PackedInt64Array` columns for stable entity IDs and `death_tick`, plus a stable-ID-to-dense-index lookup. `death_tick` is a `SimulationClock` tick index, not a world revision or a real-time unit. The store does not own core identity, position, terrain, presentation, birth state, corpse behavior, or history.

```text
EntityStore
   entity 42 (stable ID + logical position)
      |
      |-- before: LivingState (birth_tick)
      |
      `-- after:  RemainsState (death_tick)

stable core ID and position remain
optional state transition != entity replacement
```

`PrototypeLifecycleTransition.transition_to_remains()` checks core existence, non-negative death tick, living membership, absence of remains membership, and both optional stores' binding before mutation. It then attaches remains state and removes living state; an unexpected removal failure rolls the new remains row back. It never deletes or creates a core entity, so the stable ID and logical position remain unchanged. The Living/Remains pair is mutually exclusive through this prototype transition contract.

Optional state stores describe capabilities or state slices. They do not define one exclusive global entity type, and an entity may carry multiple unrelated optional states. This phase therefore adds no `EntityType` enum, component mask, archetype, generic state machine, or ECS registry. A generic core entity may carry neither Living nor Remains state.

Movement already iterates Living membership. Removing that row naturally excludes a transitioned entity from later movement passes without a Remains-specific condition or hot-loop cost. Birth data is not copied into Remains; after transition, living age queries are invalid by contract. Durable lifecycle history is a separate future concern.

Stable-ID-preserving changes may later model cases such as construction to completed building or ground item to inventory-owned item, as well as living to remains. Only living to remains is implemented here; the other examples are not approved systems.

## Stable cross-entity owner reference probe

`PrototypeOwnerReferenceStore` proves one concrete directed reference while remaining an optional data slice bound to one `EntityStore`. Each dense row contains a subject stable ID and an owner stable ID in separate `PackedInt64Array` columns. A dictionary maps only subject stable IDs to ephemeral dense row indices. The target value is never an `EntityStore` dense index, `Node`, `Object`, `Resource`, or `NodePath`.

```text
Entity A stable ID
    |
    |-- LivingState (optional)
    `-- PrototypeOwnerReference
            | stable owner target ID
            v
         Entity B
```

Both IDs must exist in the bound core store when a reference is first attached or explicitly updated. Updating changes the target column in place and does not duplicate the subject row. Clearing uses swap-remove, repairs the moved subject mapping, and removes neither core entity nor any other optional state. Self-reference is technically valid at this storage layer because gameplay ownership rules remain undecided.

Stable IDs in this slice are scoped to the bound `EntityStore`. The store never consults another world/store instance, and `is_bound_to()` lets an orchestrator reject mismatched owners. Because the stored value is intentionally a bare int64, it cannot identify that a caller obtained the same numeric value from a different `EntityStore`; globally namespaced cross-world IDs are not proven here.

Stored reference is not the same as a currently resolved runtime target. If Entity B is removed, Entity A's row keeps B's old stable ID while `is_owner_resolved(A)` becomes false:

```text
A.owner_id = old B stable ID
resolve(A.owner_id) = missing
```

`EntityStore` never reuses IDs, so a later Entity C receives a different ID and cannot silently hijack A's stale reference. This raw-versus-resolved distinction leaves room for future stale-reference diagnosis, history, and serialization without implementing any of those systems now.

Target deletion does not cascade to the subject, clear the row, or change Living/Remains state. Source deletion still requires explicit orchestration: clear its optional owner row before removing the core subject. A living-to-remains transition preserves the independent owner row because it preserves the same core subject ID.

This owner name is an architecture probe, not ownership gameplay. There is no reverse index, many-to-many graph, relation type enum, generic relationship table, registry, event bus, cascade policy, inventory, building/kingdom/pet/legal ownership, or serializer. Additional real relationships must justify any shared abstraction later.

`DebugEntityRenderer` is one presentation `Node2D` that copies logical positions and current Living/Remains presentation membership only on explicit refresh, then draws all markers in one `_draw()` pass. Thirty-two deterministic non-water positions make the preview inspectable; there is no Node per entity and the renderer never owns entity data.

## First autonomous lifecycle loop

```text
Render delta
    |
    v
SimulationClock
    |
    v fixed tick
PrototypeAgingSystem
    |
    v PrototypeLifecycleTransition
LivingStateStore -> RemainsStateStore
    |
    v same tick, living membership already updated
PrototypeEntityMovement
    |
    v living members only
EntityStore positions
```

`PrototypeAgingSystem` is a stateless, data-only fixed-tick pass over `LivingStateStore`. Age remains derived as `current_tick - birth_tick`; no age column is stored or incremented. A small stable-ID integer hash maps each current prototype entity to a lifespan from 120 through 200 ticks. This is an interactive engineering rule, not game balance, biological design, species architecture, or a content definition. It uses no global RNG and allocates no per-entity RNG.

When derived age reaches or exceeds that threshold, the aging pass calls the existing `PrototypeLifecycleTransition` with `death_tick = current_tick`. It does not duplicate death logic. The transition preserves core identity and position, removes Living membership, adds Remains membership, and leaves independent optional state such as owner references untouched. Aging/death changes entity optional state only and cannot advance the `WorldGrid` revision.

The pass mutates the dense Living store while iterating it. After a successful transition it deliberately keeps the current dense index so the row swapped into that slot is evaluated next; otherwise it advances. This prevents same-tick deaths from skipping rows without allocating a full living-ID snapshot.

Main uses an explicit `aging -> movement` order for every consumed tick. An entity that dies on a tick is therefore absent from movement membership on that same tick. No registry, scheduler, system graph, health layer, species definition, reproduction, needs, event bus, or lifespan store was introduced.

The single `DebugEntityRenderer` now copies core positions plus Living/Remains membership on explicit refresh. Living entities use the existing bright square marker; remains use a muted cross. Catch-up still processes every authoritative tick and performs at most one presentation refresh at frame end when movement or lifecycle state changed. The renderer reads but never owns or mutates any authoritative store.

## Prototype deterministic movement

```text
RENDER FRAME
    ↓ delta
SimulationClock
    ↓ zero or more fixed ticks
PrototypeEntityMovement
    ↓ updates logical positions
EntityStore (authoritative entity state)
    ↓ one copied snapshot after all due ticks, only if movement occurred
DebugEntityRenderer
```

`PrototypeEntityMovement.step(world, entities, living_states, tick_index)` is stateless and data-only. It iterates only the optional living-state membership, then resolves each member's logical position through `EntityStore`. For each living member it hashes the stable entity ID with the fixed-tick index, uses the low two bits as a starting cardinal direction, and tries all four cardinal neighbors in stable rotation order. The first in-bounds, valid, non-WATER destination is written through `EntityStore`; otherwise the entity stays. Each participating entity therefore moves by zero or one logical cell per tick. A core entity without living state is excluded.

Movement reads `WorldGrid`, mutates `EntityStore`, and does not mutate `WorldGrid`. Consequently entity motion cannot create world-layer invalidations or advance the world revision. The prototype produces only a moved-entity count; no entity change set, event stream, entity revision, or per-entity event allocation exists.

The pass uses `LivingStateStore.get_dense_count()` plus direct dense ID access instead of allocating full-store snapshots each tick. Positions remain core `EntityStore` data. Stable entity IDs are identity; dense indices in either store are ephemeral storage positions. A dense index may change after swap-remove and cannot be persisted as identity. Faz 3C performs no create/remove during movement, so the living dense layout remains stable for the duration of each pass. If lifecycle mutation and iteration later share a tick, that contract must be revisited.

High-frequency systems should avoid repeated full-store snapshots and redundant coordinate transforms while preserving authoritative encapsulation. The safe `WorldGrid.get_terrain()` path therefore computes its chunk coordinate once, derives the local coordinate from it, and still delegates to `WorldChunkData` validation; no unchecked storage API is exposed.

Decisions use stable ID plus tick, never dense index or global RNG, so different dense ordering and render-frame schedules preserve per-identity results. Main processes all due simulation ticks, accumulates whether any entity moved, and refreshes presentation once at frame end rather than once per catch-up tick.

WATER blocking belongs only to this prototype behavior; it is not a world-level passability rule or a universal species constraint. Living membership does not mean every future living category walks: rooted life, swimmers, flyers, riders, vehicles, and terrain-dependent movement remain separate future capabilities. Multiple entities may occupy the same logical cell. Sub-cell positions, movement speed, terrain costs, collision, occupancy, interpolation, targets, navigation, and pathfinding remain undecided and unimplemented.

## Current project structure

- `project.godot`: Godot project identity and pixel-art-friendly rendering defaults.
- `scenes/main.tscn`: minimal `Main -> World` bootstrap scene.
- `scripts/main.gd`: small seeded world initialization and debug-change orchestration.
- `scripts/world/`: authoritative world data classes.
- `scripts/generation/`: deterministic initial-data producer and data-only fingerprint helper.
- `scripts/simulation/`: data-only fixed-step simulation clock.
- `scripts/simulation/prototype_aging_system.gd`: deterministic derived-age lifecycle pass.
- `scripts/simulation/prototype_entity_movement.gd`: stateless cardinal one-cell prototype movement pass.
- `scripts/entities/`: generic authoritative stable-ID/position storage and separate optional living-state storage.
- `scripts/presentation/`: replaceable palette, rasterization, chunk rendering, inspection, and preview-fixture code.
- `tests/world_data_test.gd`: headless data-only contract tests.
- `tests/terrain_visualization_test.gd`: headless image/presentation contract tests.
- `tests/world_change_set_test.gd`: headless revision, immutability, ordering, multi-consumer, and incremental-refresh contract tests.
- `tests/world_layer_extensibility_test.gd`: headless two-layer storage, bounds, change-category, revision, stability, and renderer-independence tests.
- `tests/elevation_visualization_test.gd`: headless grayscale, overlay lifecycle, alignment, partial-edge, category-isolation, fixture, and inspector tests.
- `tests/world_generation_test.gd`: headless seed, RNG isolation, fingerprint, bounds, chunk-independence, and initialization-batch tests.
- `tests/simulation_clock_test.gd`: headless fixed-step accumulation, catch-up, schedule-equivalence, and revision-independence tests.
- `tests/entity_store_test.gd`: headless lifecycle, bounds, stable-ID, swap-remove, stale-ID, and snapshot tests.
- `tests/living_state_store_test.gd`: headless optional membership, age derivation, heterogeneity, ownership, and swap-remove tests.
- `tests/debug_entity_renderer_test.gd`: headless copied-snapshot and no-per-entity-Node presentation tests.
- `tests/entity_movement_test.gd`: headless deterministic movement, terrain/bounds, dense-order, render-schedule, and refresh-coalescing tests.
- `tests/prototype_aging_system_test.gd`: headless lifespan, threshold, multi-death, tick-order, schedule, revision, and reference-survival tests.
- `benchmarks/world_data_sanity.gd`: small non-gating baseline workload.
- `benchmarks/world_generation_sanity.gd`: one small non-gating generated-world baseline workload.
- `benchmarks/entity_store_sanity.gd`: one non-gating 10,000-row minimal entity lifecycle workload.
- `benchmarks/entity_movement_sanity.gd`: one non-gating 10,000-entity/100-tick minimal movement workload.
- `benchmarks/entity_movement_profile.gd`: development-only, non-gating component diagnosis for the minimal movement hot path.
- `benchmarks/lifecycle_simulation_sanity.gd`: non-gating 10,000-entity/250-tick aging-plus-movement workload.
- `tools/validate.ps1`: local and CI validation entry point.

## Validation guardrails

`tools/validate.ps1` resolves the repository root from its own location and validates required files, the configured main scene, Godot headless import/parser behavior, a bounded runtime smoke test, and fourteen separate suites: world data, terrain visualization, world change sets, layer extensibility, elevation visualization, generation, simulation clock, entity store, living state, remains/lifecycle transition, stable owner references, debug entity rendering, deterministic movement, and prototype aging. `.github/workflows/validate.yml` runs that same command with a checksum-verified official Godot 4.7.2 Standard binary. `tools/toolcheck.ps1` remains a separate environment inventory.
