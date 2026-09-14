# Faz 3B – Minimal Deterministic Entity Movement

Consider letting the small debug entity population move deterministically on the fixed simulation tick, remain inside world bounds, obey one minimal terrain-aware movement constraint, and refresh the single-node entity presentation when positions change.

Keep the phase narrow. Do not add pathfinding, an AI framework, needs, jobs, combat, settlements, animation, or a general movement-system architecture before the minimal deterministic behavior is proven.

Before implementation, reassess this proposal against the repository's actual state, `docs/PLANNING_GUARDRAILS.md`, and Semarel's long-term gameplay direction. `NEXT.md` remains a planning proposal, not an automatic command.
