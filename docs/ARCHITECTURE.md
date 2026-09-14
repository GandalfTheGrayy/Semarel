# Architecture

## Authoritative world data

The logical world is authoritative data. Rendering is a consumer of that data and must not become its source of truth.

```text
Authoritative World State
        WorldGrid
            ↓ owns chunks, bounds, coordinate conversion, dirty set
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
- Track changed chunks as a deduplicated dirty set.

Coordinate helpers use floor-based chunk coordinates and normalized local coordinates for any integer input. Terrain access is stricter: positions must be in `[0, world_size)`. An out-of-world read returns `TerrainTypes.INVALID`; an out-of-world or invalid-ID write returns `false`, changes nothing, and marks no chunk dirty.

World dimensions do not have to be exact multiples of the chunk size. Edge chunks retain the standard storage size while `WorldGrid` enforces the true world bounds.

Renderer-facing reads use `is_valid_chunk_position()`, `chunk_to_world_origin()`, `get_chunk_world_rect()`, and `get_chunk_terrain_copy()`. The terrain snapshot is a copy, never a mutable reference to `WorldChunkData._terrain`. `get_chunk_world_rect()` clips right and bottom edge chunks to the actual world dimensions so padded storage cells are never displayed.

## WorldChunkData responsibilities

- Own one chunk's terrain layer as a flat `PackedByteArray`.
- Validate local coordinates.
- Read, write, and fill terrain values.
- Centralize flat indexing as `index = y * chunk_size + x`.

The storage creates no per-cell Node, Object, Dictionary, or Resource. Terrain values are compact byte-sized IDs. `WATER`, `LAND`, `SAND`, and `ROCK` are prototype values, not final game-design commitments.

## Change tracking

`WorldGrid.set_terrain()` marks the affected chunk dirty only when the stored value changes. The dirty set deduplicates repeated changes within a chunk. Consumers can inspect it, clear it, or consume its current contents in one operation. There are deliberately no per-cell signals, gameplay-specific change types, event bus, or region system in Faz 1A.

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

The renderer supports `rebuild_all()` and `refresh_chunks(changed_chunks)`. Same-sized textures use `ImageTexture.update()`; only size changes allocate a new texture. A small CPU `Image` cache keeps the latest rasterized presentation state deterministic and testable; it is derived data and is never authoritative.

Presentation state can be destroyed and rebuilt from `WorldGrid`. Deleting every `Image`, `ImageTexture`, and `Sprite2D` does not affect terrain data.

The renderer observes a dirty-coordinate snapshot supplied by orchestration and does not call `consume_dirty_chunks()`. The current controller clears initialization dirtiness only after the sole consumer has rebuilt. Faz 1C will address generic runtime change propagation to multiple consumers without adding gameplay-specific mutations.

`WorldPreviewFixture` is an explicit deterministic debug fixture, not a procedural world generator. `WorldInspector` maps display coordinates through the renderer scale, reads `WorldGrid`, and never writes terrain.

## Current project structure

- `project.godot`: Godot project identity and pixel-art-friendly rendering defaults.
- `scenes/main.tscn`: minimal `Main -> World` bootstrap scene.
- `scripts/main.gd`: startup smoke marker only.
- `scripts/world/`: authoritative world data classes.
- `scripts/presentation/`: replaceable palette, rasterization, chunk rendering, inspection, and preview-fixture code.
- `tests/world_data_test.gd`: headless data-only contract tests.
- `tests/terrain_visualization_test.gd`: headless image/presentation contract tests.
- `benchmarks/world_data_sanity.gd`: small non-gating baseline workload.
- `tools/validate.ps1`: local and CI validation entry point.

## Validation guardrails

`tools/validate.ps1` resolves the repository root from its own location and validates required files, the configured main scene, Godot headless import/parser behavior, a bounded runtime smoke test, the world-data suite, and the terrain-visualization suite. `.github/workflows/validate.yml` runs that same command with a checksum-verified official Godot 4.7.2 Standard binary. `tools/toolcheck.ps1` remains a separate environment inventory.
