# Agent instructions — SpatialRehab

Rules for any coding agent (human-directed or autonomous) working in this repository.

## CHANGELOG (required)

**Always record edits in `CHANGELOG.md`.**

Whenever you change anything in this repo — code, project config, assets, docs, scaffolding, dependencies, signing/bundle settings, or generated project files — you must update `CHANGELOG.md` in the **same change set** (same PR/commit batch) as the edit.

### What to write

- Use a short, dated entry under the appropriate section (prefer **Keep a Changelog** style: `Added` / `Changed` / `Fixed` / `Removed` / `Security`).
- One bullet per meaningful change; say *what* changed and *why* if non-obvious.
- If there is no existing section for today, create one: `## YYYY-MM-DD`.
- Do **not** skip the changelog for “tiny” edits. If it is worth committing, it is worth a changelog line.
- Do **not** invent user-facing release notes for unreleased internal noise that never lands — but if the file on disk changes in a commit, log it.

### When this does *not* apply

- Read-only exploration (no file writes).
- Purely local/uncommitted experiments you are about to discard without committing.

If you are about to commit or hand work back and you edited files but did not touch `CHANGELOG.md`, **stop and add the entry first**.
