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

## Metrics not yet represented

| Metric | Current value |
| --- | --- |
| NPC count | Not implemented or measured |
| Simulation tick time | Not implemented or measured |
| Render FPS | Not measured |
| Frame time | Not measured |
| Memory use | Not measured |
| Navigation/pathfinding cost | Not implemented or measured |

Future representative benchmark reports should record the build/commit, hardware context, scenario/seed, duration, sampling method, and raw output. Do not compare numbers from non-equivalent workloads.
