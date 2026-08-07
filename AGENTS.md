# Agent instructions — SpatialRehab

Rules for any coding agent (human-directed or autonomous) working in this repository.

## Team

Five-person team. When work touches one of these areas, loop in (or attribute to) the responsible person.

| Person | Responsibility | Deliverables |
|---|---|---|
| Aditya | 3D Assets & Environment — create interactive 3D models and scenes | Kitchen, bedroom, medicine bottles, groceries, furniture, hand-interactable objects |
| Brian | UX/UI & Spatial Design — design the user experience and guidance | Menus, onboarding, arrows, highlights, prompts, progress indicators, accessibility, interaction flow |
| JingTong | Apple Vision Pro Development — build the application in RealityKit/SwiftUI | Scene setup, object interactions, hand tracking, gaze input, game logic, scoring, data storage |
| Nicole | Clinical Research & Content — ensure exercises are evidence-based | Research dementia rehabilitation, design cognitive exercises, validate task difficulty, define success metrics |
| Basil | AI, Analytics & Integration — personalization and progress tracking | Adaptive difficulty, performance metrics, therapist dashboard, data visualization, presentation/demo support |

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
