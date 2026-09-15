# Future System Constraints

This document records broad architecture capability targets for Semarel's long-term world simulation. It is not an implementation roadmap and does not approve any specific system for immediate development.

## Entity and living-world breadth

The architecture should remain capable of representing heterogeneous world entities, including humans, animals, monsters or fantastical creatures, plants and other living environmental entities, buildings, items, resources, projectiles, entities with different movement modes, entities related to settlements and civilizations, and other future world entities.

Living-world capability targets include birth, growth, aging, death, lifecycle, possible reproduction/family/ancestry, health, injury, disease, needs, varied individual state, and individual traits such as personality and skills. These targets do not imply that every entity is living or that every living entity carries every possible state.

Movement capability targets include walking, swimming, flying, riding, vehicles, and terrain-dependent movement. No single membership category should permanently imply one movement capability.

## Entity composition, identity, and persistence

- One entity may carry multiple independent optional state slices at the same time.
- Optional state may be attached or detached at runtime, and a form or lifecycle transition may preserve the same stable core entity ID.
- Future state may reference other entities by stable ID. The model should support preserving those references across save/load without silently retargeting them.
- Entity definitions should remain open to future data-driven and moddable content rather than requiring one closed entity-type enum.
- The disappearance of an important entity may later emit durable history or event records without requiring that entity's runtime state to remain alive.

These are capability constraints only. Faz 3D implements only the narrow living-to-remains transition. Faz 3E proves one concrete subject-to-owner reference stored as a stable target ID, including detectable stale-target behavior without silent retargeting. A generic relationship graph, persistence serialization, definition/mod loading, and historical-event systems remain unimplemented and are not approved by this document.

## Constructed, political, and economic worlds

The architecture should leave room for buildings and their construction, damage, and destruction; villages, cities, and capitals; ownership and borders; kingdoms or states; leaders; diplomacy; alliances; wars; rebellion; conquest; and other political processes.

Economic capability targets include resources, production, storage, trade, possible money and taxation, jobs and professions, inventory, weapons, armor, tools, and items.

Combat capability targets include individual combat, ranged attacks and projectiles, armies, and sieges. These are distinct domains whose mechanics and data requirements remain undecided.

## Environment, society, and history

Environmental capability targets include temperature, moisture, weather, seasons, fire, floods, drought, vegetation, world resources, agriculture, disasters, god powers, magic, and other supernatural systems.

Social and historical capability targets include social relations, family, friendships, hostility, migration, possible crime and leadership, ancestry, notable events, and inspectable individuals, settlements, and world history.

## Scale and product longevity

Semarel should remain capable of supporting long-lived saveable worlds, large populations, and future moddability. Stable identity, deterministic simulation boundaries, and authoritative data separation should also avoid unnecessarily closing the possibility of multiplayer or networking. This does not authorize save/load, mod APIs, or networking implementation today.

## Interpretation rule

Everything above is an architecture capability target. It is not an exact mechanic, implementation order, final data schema, guaranteed UI design, or final game-balance decision. Each domain must be planned separately from real requirements and repository evidence before implementation.
