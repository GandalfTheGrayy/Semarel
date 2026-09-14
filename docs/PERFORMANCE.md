# Performance

## Faz 1A data sanity baseline

This is a small data-layout sanity measurement, not a performance target, optimization claim, or CI pass/fail threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-14 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Host | Windows 10 10.0.19045; AMD Ryzen 7 5800H; 15.3 GiB RAM |
| Workload | Create a 256×256-cell world, then run 100,000 deterministic terrain sets and 100,000 matching gets |
| Chunk layout | 64×64 cells; 4×4 chunks; 65,536 logical cells |
| World initialization | 0.112 ms |
| Set/get loop | 519.377 ms |
| Checksum | 250000 |

Command:

```powershell
godot --headless --path . --script res://benchmarks/world_data_sanity.gd
```

The measurement is a single local run and is hardware-dependent. Future comparisons must use the same workload and should take repeated samples before drawing conclusions.

## Faz 1B presentation sanity

- A 256×256-cell preview with 64×64 chunks creates 16 `Sprite2D` chunk visuals, not 65,536 cell Nodes.
- Each full chunk snapshot is 4,096 terrain bytes; partial edge chunks rasterize only their clipped world rectangle.
- Interactive OpenGL inspection on the recorded workstation showed no obvious stall, blurred filtering, chunk gap, or overlap.
- No render-time target or CI performance threshold was introduced, and no numeric renderer benchmark is claimed.

## Faz 1C change propagation sanity

- Pending metadata contains unique changed chunk coordinates, not per-cell events or a full-world snapshot.
- The automated batch test changes 100 cells in one chunk and produces one terrain-chunk invalidation.
- Committing copies only changed chunk-coordinate metadata into a stable change set; no new performance target or benchmark threshold was introduced.

## Faz 1D multi-layer storage sanity

- A 256×256 logical world contains 65,536 cells. The prototype raw arrays therefore contain approximately 65,536 terrain bytes plus 65,536 elevation bytes: 131,072 bytes total.
- This is a raw `PackedByteArray` payload calculation only. Chunk objects, arrays, dictionaries, allocator behavior, and other container overhead are excluded.
- Terrain and elevation remain compact arrays with no per-cell Objects. No new benchmark, optimization claim, performance target, or CI threshold was introduced.

## Faz 1E secondary presentation sanity

- A 256×256 preview with 64×64 chunks creates 16 terrain visuals plus 16 elevation overlay visuals. Presentation node count therefore scales with chunk count, not 65,536 cells.
- Elevation `Image`, `ImageTexture`, and `Sprite2D` objects are derived caches that can be discarded and rebuilt from `WorldGrid`.
- Category-specific tests confirm that terrain-only batches skip elevation texture refresh and elevation-only batches skip terrain texture refresh.
- No FPS target, numeric rendering benchmark, optimization claim, or CI performance threshold was introduced.

## Faz 2A generation sanity baseline

This is one local data-generation sanity measurement, not a performance target, optimization claim, or CI threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-14 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | Create a 256×256 world, generate terrain and elevation with seed `12345`, then commit one initial batch |
| Generator version | 1 |
| Chunk layout | 64×64 cells; 4×4 chunks; 65,536 logical cells |
| Generation | 527.994 ms |
| Initial change set | revision 1; 16 terrain chunks; 16 elevation chunks |
| Terrain fingerprint | 451630829 |
| Elevation fingerprint | 1135444898 |
| Combined fingerprint | 1217889498 |

Command:

```powershell
godot --headless --path . --script res://benchmarks/world_generation_sanity.gd
```

The measurement is hardware-dependent and includes ordinary `WorldGrid.set_*` validation/change tracking for each logical cell. It does not justify optimization or define production-generation performance. Future comparisons should use the same seed, generator version, world size, build, and workload.

## Faz 2B coherent generation sanity baseline

This is one local generator-v2 sanity measurement, not a performance target, optimization claim, distribution target, or CI threshold. V1 and v2 implement different algorithms, so the timing difference is descriptive only.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | Create a 256×256 world, generate coherent terrain/elevation with seed `12345`, then commit one initial batch |
| Generator version | 2 |
| Chunk layout | 64×64 cells; 4×4 chunks; 65,536 logical cells |
| Generation | 508.313 ms |
| Initial change set | revision 1; 16 terrain chunks; 16 elevation chunks |
| Terrain fingerprint | 944353488 |
| Elevation fingerprint | 1954471561 |
| Combined fingerprint | 1993745908 |
| Terrain distribution | WATER 46.053%; SAND 3.339%; LAND 41.348%; ROCK 9.261% |

The benchmark command remains:

```powershell
godot --headless --path . --script res://benchmarks/world_generation_sanity.gd
```

The measured terrain mix merely confirms that seed `12345` did not collapse to one class. It is not a game-balance or world-design target.

## Faz 3A entity-store sanity baseline

This is one local compact-storage lifecycle sanity measurement, not a target, scalability claim, NPC benchmark, or CI threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | Create 10,000 minimal ID/position entities, perform 100,000 deterministic reads plus position updates, then remove every fourth original ID |
| Logical bounds | 256×256 cells |
| Create | 8.711 ms |
| Read/update | 183.413 ms |
| Remove 2,500 | 3.172 ms |
| Final count | 7,500 |
| Checksum | 560189424 |

Command:

```powershell
godot --headless --path . --script res://benchmarks/entity_store_sanity.gd
```

The workload measures only stable-ID lookup, packed logical positions, and swap-remove bookkeeping on one machine. It includes no AI, movement policy, spatial query, rendering, navigation, or real NPC data and does not establish supported population size.

## Metrics not yet represented

| Metric | Current value |
| --- | --- |
| NPC count | No NPC model; 32 stationary debug entities in preview and a 10,000-row data-store sanity workload only |
| Simulation tick time | No simulation workload; fixed-clock schedule correctness only |
| Render FPS | Not measured |
| Frame time | Not measured |
| Memory use | Not measured |
| Navigation/pathfinding cost | Not implemented or measured |

Future representative benchmark reports should record the build/commit, hardware context, scenario/seed, duration, sampling method, and raw output. Do not compare numbers from non-equivalent workloads.
