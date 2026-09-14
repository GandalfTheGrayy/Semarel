# Semarel Codex Rules

Before every task:

1. Read `PROJECT_CONTEXT.md`.
2. Read `NEXT.md`.
3. Run `git status`.
4. Inspect the code and documentation relevant to the task.
5. Prefer the current repository state over old chat context unless the user explicitly says otherwise.

Engineering rules:

- Use Godot 4.x Standard and GDScript; do not add C#/.NET.
- Keep simulation logic modular and separable from visual representation.
- Design for thousands of entities without running heavy AI for every NPC every render frame.
- Allow simulation frequency to differ from rendering frame rate.
- Keep future chunking, spatial partitioning, local navigation updates, deterministic simulation, and persistent terrain mutation possible.
- Avoid unnecessary scene-tree Nodes and hot-path allocations. Measure before optimizing.
- Inspect before rewriting, preserve unrelated working behavior, keep changes task-scoped, test meaningful changes, and never hide errors.
- Record important architecture and design decisions in the appropriate repository documents.
- After every meaningful code or Godot project change, run `.\tools\validate.ps1` by default. Run relevant benchmarks for performance work. Use `toolcheck.ps1` only when the development environment is in question.

At the end of every completed task:

1. Run relevant validation and tests.
2. Update `PROJECT_CONTEXT.md`.
3. Append a concise entry to `TASK_LOG.md`.
4. Update `NEXT.md`.
5. Update architecture, design, performance, or setup documents when relevant.
6. Review `git diff` and `git status`.
7. Commit with a meaningful message and push the current branch to `origin`.
8. Report the commit hash and push result.

Leave the repository understandable to a new Codex session. Do not implement planned gameplay merely because it appears in the long-term design documents.
