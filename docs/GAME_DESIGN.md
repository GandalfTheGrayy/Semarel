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

Faz 1E's grayscale gradient, semi-transparent overlay, `E` toggle, and unitless inspector value are debug presentation choices. They do not establish final elevation art, map modes, UI, physical units, or gameplay meaning.

Faz 2A's generator version `1`, fixed preview seed `12345`, block-like prototype regions, terrain proportions, and elevation byte formula exist only to prove deterministic initialization and ownership boundaries. They do not define final world shape, terrain/elevation relationships, biome logic, naturalism, default seed, or production generation.

Faz 2B's generator version `2` is the first coherent seeded-world prototype. Its island-like radial falloff, smooth-noise parameters, relative height, shoreline band, terrain thresholds, and resulting distribution are replaceable generation choices. They do not require all Semarel worlds to be islands and do not define final sea level, beaches, mountains, elevation units, biomes, geology, or hydrology.

Faz 3A's 10 Hz fixed clock, 32 stationary debug markers, logical-cell positions, marker color/size, and minimal ID-plus-position entity schema are engineering probes. They do not define final simulation speed, entity population, creature types, movement scale, sprites, animation, AI, needs, jobs, or gameplay behavior.

Faz 3B's deterministic cardinal movement, maximum one logical cell per tick, prototype WATER blocking, and lack of occupancy are a test behavior for generic debug entities. They do not imply that final agents cannot swim, fly, sail, share cells, use sub-cell positions, move at varied speeds, pay terrain costs, animate between cells, collide, or navigate toward goals.

## Proposed / undecided

Long-term candidates include procedural world generation, mutable terrain, elevation, climate, moisture, destruction, fire and environmental simulation, vegetation, animals, large NPC populations, needs and jobs, settlements, cities, kingdoms, diplomacy, war, buildings, economy, character animation, pixel particles, weather, disasters, magic or special world effects, save/load, and thousands of simulated entities.

These are direction candidates, not implemented or individually approved specifications. Final logical resolution, terrain cell/art size, terrain type count, simulation tick rate, world dimensions, biome architecture, and detailed mechanics remain undecided.
