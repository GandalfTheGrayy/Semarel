# Faz 1C – Generic World Change Propagation & Incremental Refresh

Introduce a small generic runtime change-propagation path so one authoritative world change set can be observed by multiple consumers before it is cleared.

Use it to verify targeted terrain-renderer refreshes while keeping mutation and propagation independent from gameplay-specific concepts. Renderer, navigation, save/streaming, and future simulation consumers must not hide changes from one another through destructive consumption.

Do not add procedural generation, NPCs, combat, disasters, player powers, navigation implementation, save/load, or other gameplay systems in this phase.
