# Game Design

## Confirmed

- The game is named **Semarel**.
- It is an original 2D pixel-art god/sandbox world simulation.
- Emergent world behavior is a core direction.
- Semarel may draw high-level inspiration from the genre but must have its own systems, mechanics, visual language, and identity.
- Godot 4.x Standard and GDScript are the implementation stack.
- Authoritative world state is independent from rendering.

## Prototype implementation, not final design

Faz 1A uses `WATER`, `LAND`, `SAND`, and `ROCK` IDs only to validate compact terrain storage and access. This list does not define the final terrain catalog, biome model, art scale, or gameplay behavior.

The 64×64-cell chunk default and 256×256-cell test world are engineering prototype values. They are not final world-design constraints.

Faz 1B's blue, green, pale-yellow, and gray palette and its 2× display scale are debug presentation choices only. They are not final terrain art, biome colors, tilesets, or art scale.

Faz 1D's prototype elevation byte layer exists only to prove multi-layer world-data extensibility. Its `0–255` storage range and default `0` do not define physical height, sea level, slopes, mountains, generation, hydrology, movement cost, biome rules, or final precision.

## Proposed / undecided

Long-term candidates include procedural world generation, mutable terrain, elevation, climate, moisture, destruction, fire and environmental simulation, vegetation, animals, large NPC populations, needs and jobs, settlements, cities, kingdoms, diplomacy, war, buildings, economy, character animation, pixel particles, weather, disasters, magic or special world effects, save/load, and thousands of simulated entities.

These are direction candidates, not implemented or individually approved specifications. Final logical resolution, terrain cell/art size, terrain type count, simulation tick rate, world dimensions, biome architecture, and detailed mechanics remain undecided.
