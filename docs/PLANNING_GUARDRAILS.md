# Planning Guardrails

Semarel's long-term direction is an original, living, emergent sandbox simulation inspired at a high level by games such as WorldBox while aiming for broader systems and its own identity.

- Do not treat one user example or one current prototype system as the game's central design.
- Plan every task from the repository's real current state and the long-term product direction.
- Prefer small, testable, reversible phases.
- Consider future systems, but do not implement them before a real need exists.
- Avoid premature generic abstractions and frameworks.
- Prototype constants, debug visuals, and engineering probes are not final game-design decisions.
- Do not let debug or validation mechanisms accidentally become production architecture.
- Performance is a first-class requirement for large worlds and many entities, but measure before optimizing.
- `NEXT.md` is a proposal, not an automatic command; evaluate it with repository evidence and product direction.
- Reassess progress against the game goal after several infrastructure phases; do not extend foundation work indefinitely.
- Prefer a correction or refactor phase over a new feature when the current direction creates costly technical debt.
- Move toward real gameplay and simulation systems once the architecture has been proven sufficiently.
- The Faz 1-3 foundation period is complete for current gameplay work: it proved authoritative mutable world data, deterministic generation, fixed simulation time, generic stable-ID entities, composable optional state, identity-preserving lifecycle transition, stable cross-entity references, and a measurement/validation baseline.
- From Faz 4 onward, new infrastructure should normally be justified by an actual gameplay or simulation requirement. Do not extend the foundation merely because another generic boundary could be imagined.
- Defer the proposed data-driven definition boundary until at least two real species, building, item, or comparable content consumers expose shared requirements; prototype constants alone do not justify a registry or loading pipeline.
- Before opening a new domain-specific gameplay/content axis such as characters, animals, monsters, buildings, settlements, combat, economy, needs, species, or similar systems, stop at a planning checkpoint and ask the user which requirements that infrastructure must support. Do not choose the domain direction automatically. This does not require renewed approval for technical corrections, tests, performance work, or continuation of an already approved narrow slice.

This document provides project-direction and planning guardrails. It does not replace the Codex implementation rules in `AGENTS.md`.
