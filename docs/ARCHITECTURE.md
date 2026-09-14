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
WorldGenerator version 1
        ↓ writes initial logical terrain/elevation values
WorldGrid
        ↓ owner/orchestrator calls commit_changes()
Initial WorldChangeSet
        ↓
Presentation / future consumers
```

`WorldGenerator` is a producer; `WorldGrid` remains the authoritative runtime owner. The generator receives a target grid for one call, writes only through its public coordinate APIs, retains no world reference or mutable run state, and does not commit, render, or access the scene tree. The caller decides when initialization is complete and commits the accumulated terrain/elevation invalidations as one batch.

Generation uses an explicit integer seed and a fresh local `RandomNumberGenerator`. Two salt values are drawn locally, after which prototype terrain regions and elevation bytes are derived from logical world coordinates. Global RNG use elsewhere cannot perturb output. The algorithm iterates world coordinates and never reads chunk coordinates, so changing only the chunk partition preserves identical logical values and creates no chunk-boundary generation seams.

`WorldGenerator.GENERATOR_VERSION = 1` identifies the current deterministic algorithm. This is a small future-facing identifier, not a save compatibility framework. The fixed preview seed `12345`, version, region size, terrain proportions, and elevation formula are development probe values rather than final game rules.

`WorldFingerprint` reads authoritative terrain/elevation in stable row-major logical order and produces separate and combined non-cryptographic checksums. It exists for reproducibility tests and diagnostics, contains no presentation data, and does not make the generated algorithm final.

`WorldPreviewFixture` remains a presentation-test fixture for known pixel expectations. It is distinct from `WorldGenerator`, which initializes the main preview and proves the production-facing ownership boundary. Generation means new-world creation; it is not runtime simulation and does not stand in for future climate, erosion, ecosystems, resources, or other ongoing systems.

## Current project structure

- `project.godot`: Godot project identity and pixel-art-friendly rendering defaults.
- `scenes/main.tscn`: minimal `Main -> World` bootstrap scene.
- `scripts/main.gd`: small seeded world initialization and debug-change orchestration.
- `scripts/world/`: authoritative world data classes.
- `scripts/generation/`: deterministic initial-data producer and data-only fingerprint helper.
- `scripts/presentation/`: replaceable palette, rasterization, chunk rendering, inspection, and preview-fixture code.
- `tests/world_data_test.gd`: headless data-only contract tests.
- `tests/terrain_visualization_test.gd`: headless image/presentation contract tests.
- `tests/world_change_set_test.gd`: headless revision, immutability, ordering, multi-consumer, and incremental-refresh contract tests.
- `tests/world_layer_extensibility_test.gd`: headless two-layer storage, bounds, change-category, revision, stability, and renderer-independence tests.
- `tests/elevation_visualization_test.gd`: headless grayscale, overlay lifecycle, alignment, partial-edge, category-isolation, fixture, and inspector tests.
- `tests/world_generation_test.gd`: headless seed, RNG isolation, fingerprint, bounds, chunk-independence, and initialization-batch tests.
- `benchmarks/world_data_sanity.gd`: small non-gating baseline workload.
- `benchmarks/world_generation_sanity.gd`: one small non-gating generated-world baseline workload.
- `tools/validate.ps1`: local and CI validation entry point.

## Validation guardrails

`tools/validate.ps1` resolves the repository root from its own location and validates required files, the configured main scene, Godot headless import/parser behavior, a bounded runtime smoke test, and six separate world-data, terrain-visualization, world change-set, world-layer-extensibility, elevation-visualization, and deterministic-generation suites. `.github/workflows/validate.yml` runs that same command with a checksum-verified official Godot 4.7.2 Standard binary. `tools/toolcheck.ps1` remains a separate environment inventory.
