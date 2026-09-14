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

This document provides project-direction and planning guardrails. It does not replace the Codex implementation rules in `AGENTS.md`.
