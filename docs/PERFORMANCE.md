# Performance

## Faz 4A lifecycle simulation sanity

This is one local representative aging-plus-movement measurement, not a performance target, supported-NPC claim, production tick budget, or CI threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | 10,000 core/living entities on a 256×256 all-LAND world; 250 fixed ticks of production prototype aging followed by movement |
| Prototype lifecycle | Stable-ID lifespan rule; all entities begin with `birth_tick = 0`; no benchmark-only behavior |
| Total time | 10,801.992 ms |
| Average | 43.208 ms/tick across the full 250-tick run |
| Total moved | 1,592,674 |
| Total deaths | 10,000 |
| Final state | 0 living; 10,000 remains |
| Checksum | 806,723,672 |
| World revision | 0 |

Command:

```powershell
godot --headless --path . --script res://benchmarks/lifecycle_simulation_sanity.gd
```

The average includes the declining movement population, so it is not directly comparable to the earlier constant-10,000-living movement workload. The extra aging pass uses dense Living membership, performs no per-tick full snapshot, and correctly shrinks as entities transition. This sample exposed no accidental per-tick allocation, quadratic behavior, or catastrophic regression; no optimization phase was opened.

## Faz 3D lifecycle transition note

The living-to-remains transition is an occasional data-only operation over two dense optional stores. Once Living membership is removed, the entity disappears from the existing movement iteration automatically; no remains lookup or branch was added to the per-tick movement hot loop. No new benchmark or performance threshold was introduced for this narrow slice.

## Faz 3E stable-reference note

Owner references are compact optional rows with two packed int64 columns and one subject lookup. They are not queried by any current per-tick hot loop, and target resolution is an explicit core-ID lookup only when requested. No reverse index, graph traversal, benchmark, optimization claim, or performance threshold was added.

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

## Faz 3B minimal movement sanity baseline

This is one local data-only movement-loop measurement, not a performance target, supported-NPC claim, optimization result, or CI threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | 10,000 minimal entities on a 256×256 all-LAND world for 100 deterministic movement ticks |
| Movement | Cardinal; at most one logical cell/tick; no occupancy |
| Total movement time | 5,685.570 ms |
| Average | 56.856 ms/tick |
| Total moved | 1,000,000 |
| Final checksum | 1,559,308,248 |
| World revision | 0 |

Command:

```powershell
godot --headless --path . --script res://benchmarks/entity_movement_sanity.gd
```

The workload isolates stable-ID hashing, dense position iteration, world bounds/terrain reads, and position writes. It excludes AI, needs, pathfinding, combat, social simulation, occupancy, spatial queries, entity rendering, and real agent data. The result therefore does not mean 10,000 complete NPCs are supported. No multithreading, ECS, GDExtension, SIMD, or spatial partitioning was added from this single baseline.

## Faz 3B.1 movement hot-path diagnosis

This is a local correction-phase diagnosis, not a supported-NPC claim, production tick budget, performance target, or CI threshold.

| Field | Value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Host | Windows 10 Home 10.0.19045; AMD Ryzen 7 5800H; 15.3 GiB RAM; Balanced power plan |
| Movement workload | Unchanged 10,000 minimal entities, 100 ticks, 256×256 all-LAND world |
| Repeat method | One excluded pre-sample followed by five recorded runs before and five recorded runs after |
| Before samples | 5,778.016; 5,964.710; 5,711.539; 5,646.663; 5,645.543 ms |
| Before min / median / max | 5,645.543 / 5,711.539 / 5,964.710 ms |
| After samples | 5,276.274; 5,370.259; 5,191.591; 5,239.395; 5,225.046 ms |
| After min / median / max | 5,191.591 / 5,239.395 / 5,370.259 ms |
| Median difference | -472.144 ms total; -4.721 ms/tick; -8.27% |
| Before and after result | 1,000,000 moved; final checksum 1,559,308,248; world revision 0 |

The first synchronous process run measured 7,191.933 ms after an earlier PowerShell attempt launched Godot without waiting for completion. Because that run may have overlapped those discarded processes, it was classified as a contaminated warm-up/outlier before the formal five-sample before set. It is disclosed rather than silently selected or averaged into the comparison.

The development-only `benchmarks/entity_movement_profile.gd` benchmark uses the existing production APIs. Each isolated component performs 1,000,000 operations at the same 10,000-row/100-tick scale and consumes its result through a checksum. The workloads are intentionally comparative and non-additive; their totals should not be summed into a modeled movement time.

| Diagnostic component | Before median | After median | Stable checksum/result |
| --- | ---: | ---: | --- |
| Dense iteration + stable-ID hash | 639.746 ms | 597.689 ms | 398,176,955 |
| Dense position reads | 486.305 ms | 492.376 ms | 960,688,000 |
| Safe `WorldGrid.get_terrain()` reads | 2,407.525 ms | 1,980.166 ms | 51,500,000 |
| Valid dense position writes | 788.829 ms | 783.818 ms | 10,185,230 |
| Full movement | 6,282.255 ms | 5,301.988 ms | 1,000,000 moved; checksum 1,559,308,248 |

Three recorded diagnostic runs were used on each side. The third run on both sides was slower across every component, indicating system-wide run variance rather than a component-specific reversal. The terrain-read layer remained the dominant isolated cost in every run. Its median fell by 427.359 ms (17.75%) after the correction, while the other isolated components were unchanged within the observed noise.

The correction keeps the public safe read contract intact: `WorldGrid.get_terrain()` performs its world bounds check, computes `chunk_position` once, derives `local_position` from that coordinate, and delegates to the encapsulated `WorldChunkData` safe read. No unchecked chunk API or public internal storage was introduced. Movement bounds checks, terrain-ID validation, `EntityStore`, simulation tick rate, and entity count were left unchanged because this diagnosis did not separately justify altering them.

Commands:

```powershell
godot --headless --path . --script res://benchmarks/entity_movement_sanity.gd
godot --headless --path . --script res://benchmarks/entity_movement_profile.gd
```

The remaining known cost is that safe world terrain access is still the largest isolated component in this synthetic loop. That observation does not justify breaking encapsulation or claiming a production population limit; it should be revisited only when a more representative simulation workload exists.

## Faz 3C optional living-membership sanity

This is one local heterogeneous-state boundary measurement, not a performance target, supported-population claim, production tick budget, or CI threshold.

| Field | Measured value |
| --- | --- |
| Date | 2026-09-15 |
| Build | Godot Standard 4.7.2 stable, debug/editor binary |
| Workload | 10,000 core entities, all with living state, on a 256×256 all-LAND world for 100 deterministic movement ticks |
| Stored living data | Stable entity ID + `birth_tick`; age derived on demand |
| Total movement time | 5,719.269 ms |
| Average | 57.193 ms/tick |
| Total moved | 1,000,000 |
| Final checksum | 1,559,308,248 |
| World revision | 0 |

The closest previous reference is the Faz 3B.1 corrected five-run median of 5,239.395 ms. This Phase 3C sample is 479.874 ms, or 9.16%, higher, but it is one run compared with an earlier median and the workload now includes the required living-membership layer. It is descriptive evidence only. The result is not a catastrophic 2×/3× regression, so no optimization task was opened.

The development profile measured 443.232 ms for living dense-ID/hash work, 473.398 ms for core position reads, 1,909.561 ms for safe terrain reads, 760.303 ms for writes, and 5,618.041 ms for the full movement loop. Safe terrain access remains the largest isolated component. The benchmark keeps all 10,000 entities living so it measures the same movement volume as earlier phases; it does not represent non-living exclusion ratios or complete NPC behavior.

## Metrics not yet represented

| Metric | Current value |
| --- | --- |
| NPC count | No NPC model; 32 moving debug entities in preview and separate 10,000-row data/movement sanity workloads only |
| Simulation tick time | 57.193 ms/tick in one Faz 3C run of the 10,000-core/10,000-living minimal movement workload; 52.394 ms/tick remains the earlier Faz 3B.1 corrected median |
| Render FPS | Not measured |
| Frame time | Not measured |
| Memory use | Not measured |
| Navigation/pathfinding cost | Not implemented or measured |

Future representative benchmark reports should record the build/commit, hardware context, scenario/seed, duration, sampling method, and raw output. Do not compare numbers from non-equivalent workloads.
