# Architecture

## Authoritative world data

The logical world is authoritative data. Rendering is a consumer of that data and must not become its source of truth.

```text
Authoritative World State
        WorldGrid
            ↓ owns chunks, bounds, coordinate conversion, pending changes
    WorldChunkData
            ↓ owns one logical layer
PackedByteArray terrain storage

Authoritative World State ≠ Rendering
```

`WorldGrid` and `WorldChunkData` extend `RefCounted`, not `Node`. They can therefore be created, queried, mutated, and tested without a scene tree, renderer, TileMap, sprite, texture, or camera.

## WorldGrid responsibilities

- Own the bounded logical world and its chunk collection.
- Keep the prototype chunk size in the single `DEFAULT_CHUNK_SIZE` constant (currently 64).
- Keep the prototype world size in `DEFAULT_WORLD_SIZE` (currently 256×256 cells).
- Convert `Vector2i` world coordinates to chunk and local coordinates in one place.
- Expose terrain reads and writes without exposing chunk array indexing to consumers.
- Track pending changed chunks as a deduplicated set until commit.

Coordinate helpers use floor-based chunk coordinates and normalized local coordinates for any integer input. Terrain access is stricter: positions must be in `[0, world_size)`. An out-of-world read returns `TerrainTypes.INVALID`; an out-of-world or invalid-ID write returns `false`, changes nothing, and creates no pending invalidation.

World dimensions do not have to be exact multiples of the chunk size. Edge chunks retain the standard storage size while `WorldGrid` enforces the true world bounds.

Renderer-facing reads use `is_valid_chunk_position()`, `chunk_to_world_origin()`, `get_chunk_world_rect()`, and `get_chunk_terrain_copy()`. The terrain snapshot is a copy, never a mutable reference to `WorldChunkData._terrain`. `get_chunk_world_rect()` clips right and bottom edge chunks to the actual world dimensions so padded storage cells are never displayed.

## WorldChunkData responsibilities

- Own one chunk's terrain layer as a flat `PackedByteArray`.
- Validate local coordinates.
- Read, write, and fill terrain values.
- Centralize flat indexing as `index = y * chunk_size + x`.

The storage creates no per-cell Node, Object, Dictionary, or Resource. Terrain values are compact byte-sized IDs. `WATER`, `LAND`, `SAND`, and `ROCK` are prototype values, not final game-design commitments.

## World change propagation

```text
AUTHORITATIVE MUTATION

WorldGrid.set_terrain(...)
        ↓
pending changed terrain chunks
        ↓
WorldGrid.commit_changes()
        ↓
WorldChangeSet revision N
        ↓
        ├── TerrainRenderer
        ├── future Navigation
        ├── future Save/Streaming
        └── future World Systems
```

`WorldGrid.set_terrain()` records a pending chunk only when the stored value changes. A chunk changed once or hundreds of times appears once in the next batch. `commit_changes()` sorts chunk coordinates by y then x, clears the pending set, and returns a stable `WorldChangeSet`. A non-empty commit increments the world revision; an empty commit returns an empty change set at the current revision without incrementing it.

`WorldChangeSet` is immutable by contract. It copies, deduplicates, and sorts constructor input, and `get_terrain_chunks()` returns a new array on every call. Later mutations and commits cannot change older snapshots. Consumers do not own or consume authoritative pending state.

`TerrainRenderer.apply_world_changes()` reads terrain chunk invalidations and refreshes only those visuals. The same change set remains available to any number of consumers. The revision identifies committed world-change batches; it is not a simulation tick, save version, or network sequence.

`WorldChangeSet` is an invalidation/change-summary mechanism, not a gameplay event bus and not a full cell-by-cell diff. It stores no old/new values, timestamps, actors, reasons, or undo data. Terrain chunks are its first real change category; future authoritative layers may add their own chunk invalidations when they actually exist.

## Future logical layers

Terrain is the first layer of world state, not the entire world model. A later phase can add elevation, moisture, climate, resources, ownership, or environmental state as separate packed arrays or chunk-owned data components while preserving `WorldGrid` coordinate and chunk ownership. The exact layer architecture is intentionally still open; none of those layers is implemented in Faz 1A.

Likewise, final chunk size, world size, terrain count, save format, threading model, navigation representation, and generation strategy remain open decisions.

## Presentation flow

```text
AUTHORITATIVE DATA

WorldGrid
   ↓
WorldChunkData
   ↓
PackedByteArray


PRESENTATION

WorldGrid read API
   ↓
copied terrain snapshot + clipped chunk rect
   ↓
TerrainRasterizer
   ↓
Image (one texel per logical cell)
   ↓
TerrainRenderer
   ↓
ImageTexture / Sprite2D (one visual per chunk)
```

`TerrainPalette` owns debug colors; authoritative terrain types contain no `Color`, texture, or sprite information. `TerrainRenderer` applies a presentation-only 2× scale and nearest-neighbor filtering. A 256×256 world with 64×64 chunks therefore creates 16 chunk sprites.

The renderer supports `rebuild_all()` and `apply_world_changes(change_set)`. Same-sized textures use `ImageTexture.update()`; only size changes allocate a new texture. A small CPU `Image` cache keeps the latest rasterized presentation state deterministic and testable; it is derived data and is never authoritative.

Presentation state can be destroyed and rebuilt from `WorldGrid`. Deleting every `Image`, `ImageTexture`, and `Sprite2D` does not affect terrain data.

The renderer reads the copied terrain chunk list from a committed `WorldChangeSet`. It cannot consume pending state or hide a batch from another consumer. The current controller commits fixture initialization before full rebuild and distributes each debug batch to the renderer and revision UI.

`WorldPreviewFixture` is an explicit deterministic debug fixture, not a procedural world generator. `WorldInspector` maps display coordinates through the renderer scale, reads `WorldGrid`, and never writes terrain.

The SPACE-key debug change probe is development validation, not runtime terrain-editing gameplay. Its four fixed cells straddle x/y chunk boundaries so a single batch proves targeted refresh across four chunks.

## Current project structure

- `project.godot`: Godot project identity and pixel-art-friendly rendering defaults.
- `scenes/main.tscn`: minimal `Main -> World` bootstrap scene.
- `scripts/main.gd`: startup smoke marker only.
- `scripts/world/`: authoritative world data classes.
- `scripts/presentation/`: replaceable palette, rasterization, chunk rendering, inspection, and preview-fixture code.
- `tests/world_data_test.gd`: headless data-only contract tests.
- `tests/terrain_visualization_test.gd`: headless image/presentation contract tests.
- `tests/world_change_set_test.gd`: headless revision, immutability, ordering, multi-consumer, and incremental-refresh contract tests.
- `benchmarks/world_data_sanity.gd`: small non-gating baseline workload.
- `tools/validate.ps1`: local and CI validation entry point.

## Validation guardrails

`tools/validate.ps1` resolves the repository root from its own location and validates required files, the configured main scene, Godot headless import/parser behavior, a bounded runtime smoke test, the world-data suite, terrain-visualization suite, and world change-set suite. `.github/workflows/validate.yml` runs that same command with a checksum-verified official Godot 4.7.2 Standard binary. `tools/toolcheck.ps1` remains a separate environment inventory.
