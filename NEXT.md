# Faz 1B – Terrain Visualization & World Inspection

Build a small read-only visualization and inspection path over the authoritative `WorldGrid` data introduced in Faz 1A.

The renderer must consume world data without becoming authoritative. Keep coordinate conversion centralized, make dirty chunks usable for targeted visual refreshes, and provide enough inspection to verify which logical cell/chunk is being displayed.

Do not add production procedural generation, NPCs, navigation, save/load, climate, biome, resource, ownership, combat, or unrelated gameplay systems in this phase.
