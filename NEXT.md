# Faz 3E – Stable Cross-Entity Reference Slice (Proposed Checkpoint)

Faz 3D proved that one stable core entity can change optional lifecycle state without identity or position replacement. A possible next narrow slice is one real entity-to-entity relationship that stores a stable target ID, rejects stale targets safely, cannot silently retarget because IDs are never reused, and remains compatible with future save data.

Do not implement a generic relationship graph, serializer, ownership system, family system, combat targeting, inventory, or another gameplay domain automatically. The planner must select one concrete relationship from repository and product requirements, then reassess it against `docs/PLANNING_GUARDRAILS.md` and `docs/FUTURE_SYSTEM_CONSTRAINTS.md`. `NEXT.md` is a proposal, not an automatic command.
