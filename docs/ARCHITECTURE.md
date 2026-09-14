# Architecture

## Current project structure

- `project.godot`: Godot project identity and pixel-art-friendly rendering defaults.
- `scenes/main.tscn`: minimal `Main -> World` bootstrap scene.
- `scripts/main.gd`: startup smoke marker only.
- `assets/`: future game-ready art and audio, split into a few broad categories.
- `data/`, `shaders/`, `tools/`, `tests/`, and `benchmarks/`: focused homes for future real artifacts.

No gameplay subsystem architecture exists yet.

## Guiding principles

- Authoritative simulation state should not depend unnecessarily on scene-tree presentation Nodes.
- Simulation updates and rendering should be able to run at different frequencies.
- Data layouts should remain compatible with large populations, future chunks/spatial partitioning, deterministic reproduction, and local terrain/navigation updates.
- Avoid speculative subsystem trees. Add modules and directories when real implementation requires them.
- Establish measurements before making optimization claims or complex performance tradeoffs.
