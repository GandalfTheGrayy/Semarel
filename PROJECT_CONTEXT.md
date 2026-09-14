# Semarel Project Context

## Current state

- Purpose: an original large-scale 2D pixel-art god/sandbox world simulation named **Semarel**.
- Repository: `https://github.com/GandalfTheGrayy/Semarel`.
- Engine: Godot Standard 4.7.2 stable.
- Language: GDScript.
- **Faz 1A – Authoritative World Data Foundation** is complete, pushed, and validated on `main`.
- **Faz 1B – Terrain Visualization & World Inspection** is complete, pushed, and validated on `main`.
- **Faz 1C – Generic World Change Propagation & Incremental Refresh** is complete, pushed, and validated on `main`.
- Current completed phase: **Faz 1D – Second Logical World Layer Extensibility Probe**.
- Next phase: **Faz 1E – Secondary Layer Visualization & Inspection Probe**.

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
- `WorldInspector` reports read-only world, chunk, local, terrain-name, and terrain-ID information under the mouse.
- `WorldPreviewFixture` creates a deterministic debug island solely for presentation verification; it is not production generation.
- The 256×256 preview produces 16 chunk visuals, not 65,536 cell Nodes.
- Prototype elevation is a second independent byte-sized scalar layer with default value `0`; its range and physical/gameplay meaning are not final design decisions.
- `WorldChangeSet` represents one committed world-change batch with a revision and separate, deterministically ordered terrain/elevation chunk invalidations.
- `WorldGrid.commit_changes()` separates pending mutations from stable multi-consumer snapshots and advances revision only for non-empty batches.
- The SPACE-key `DebugWorldChangeProbe` path changes four cells across four chunk boundaries and routes one committed change set to the renderer and debug UI.

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
- Old change sets remain stable after later world mutations and commits.

## Confirmed decisions

- Godot 4.x Standard with GDScript and a 2D workflow.
- Nearest-neighbor canvas texture filtering and integer-friendly stretch scaling.
- Authoritative world state and visual representation are separate concerns.
- Terrain is the first logical world layer, not the complete world model.
- Cell data uses compact storage; there is no per-cell Node, Object, Dictionary, or Resource.
- Prototype elevation is an architecture probe, not a final 8-bit elevation, sea-level, slope, mountain, hydrology, or gameplay system.
- World-change revisions identify committed non-empty batches only; they are not simulation ticks, save versions, or network sequence numbers.
- Semarel may take high-level inspiration from emergent sandbox simulations, but its systems, mechanics, identity, and visual language must be original.

## Open decisions

Final chunk size, logical world size, terrain type count, terrain art scale, biome architecture, elevation representation/precision/meaning, climate simulation, generation algorithm, fluid simulation, navigation, save format, and threading model remain intentionally undecided.

## Verified development tools

Godot, Git, Git LFS, Python, pip, ImageMagick, FFmpeg, ffprobe, SoX, Inkscape CLI, ripgrep, jq, 7-Zip CLI, and hyperfine are available. Exact versions and paths are in `docs/DEVELOPMENT_SETUP.md` and can be rechecked with `tools/toolcheck.ps1`.

## Known problems and performance data

- Known project problems: none in the implemented Faz 1A–Faz 1D scope after local validation.
- One data-only baseline has been recorded in `docs/PERFORMANCE.md`; it is not a performance target or CI threshold.
- Production terrain art, procedural generation, NPCs, navigation, save/load, elevation presentation/gameplay, and further logical layers remain unimplemented by design.

## Repository rules

- Treat current code, documentation, and Git history as the durable source of truth.
- Preserve unrelated user work and inspect existing behavior before changing it.
- Keep tasks scoped, test meaningful changes, update context/log/next documents, review diffs, commit, and push.
- Do not silently promote proposals to confirmed features.
- Do not apply Git LFS broadly to all PNG files; add targeted patterns only for genuinely large binary sources.
