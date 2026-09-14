# Semarel Project Context

## Current state

- Purpose: an original large-scale 2D pixel-art god/sandbox world simulation named **Semarel**.
- Repository: `https://github.com/GandalfTheGrayy/Semarel`.
- Engine: Godot Standard 4.7.2 stable.
- Language: GDScript.
- Current phase: **Faz 0 – repository and development environment preparation** is complete.
- Current task: maintain the validated bootstrap and prepare the repository for Faz 1.
- Next phase: **Faz 1 – Dünya Temsili ve Terrain Temeli**.

## Implemented systems

- A valid Godot project exists.
- `scenes/main.tscn` contains only a minimal `Main -> World` bootstrap hierarchy.
- `scripts/main.gd` provides a startup marker for smoke validation.
- No gameplay, terrain, NPC, kingdom, combat, economy, procedural generation, navigation, weather, disaster, or save/load system has been implemented.

## Current architecture

- `Main` is the application root and `World` is an empty 2D placeholder.
- Authoritative simulation state and visual representation will be kept separable as systems are introduced.
- The repository currently contains only the minimal directories needed for the next phase.

## Confirmed decisions

- Godot 4.x Standard with GDScript and a 2D workflow.
- Nearest-neighbor canvas texture filtering and integer-friendly stretch scaling.
- The final logical resolution and terrain cell/tile size remain undecided.
- Semarel may take high-level inspiration from emergent sandbox simulations, but its systems, mechanics, identity, and visual language must be original.
- Performance will be measured; no benchmark claims exist yet.

## Verified development tools

Godot, Git, Git LFS, Python, pip, ImageMagick, FFmpeg, ffprobe, SoX, Inkscape CLI, ripgrep, jq, 7-Zip CLI, and hyperfine are available. Exact versions and paths are in `docs/DEVELOPMENT_SETUP.md` and can be rechecked with `tools/toolcheck.ps1`.

## Known problems and performance data

- Known project problems: none at the end of Faz 0.
- Performance measurements: none; gameplay and benchmark workloads do not exist yet.

## Repository rules

- Treat current code, documentation, and Git history as the durable source of truth.
- Preserve unrelated user work and inspect existing behavior before changing it.
- Keep tasks scoped, test meaningful changes, update context/log/next documents, review diffs, commit, and push.
- Do not silently promote proposals to confirmed features.
- Do not apply Git LFS broadly to all PNG files; add targeted patterns only for genuinely large binary sources.
