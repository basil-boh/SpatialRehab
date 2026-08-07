# Agent instructions — SpatialRehab

Rules for **any** coding agent working in this repository — Grok, Claude, Cursor, Codex, Copilot, or any other provider. These rules are provider-agnostic.

| File | Who reads it |
| --- | --- |
| `AGENTS.md` | Default entry for multi-agent / provider-agnostic harnesses |
| `CLAUDE.md` | **Same content** — entry for Claude Code (auto-loaded) |

Keep `AGENTS.md` and `CLAUDE.md` in sync. When you edit one, update the other to match.

## Team

Five-person team. When work touches one of these areas, loop in (or attribute to) the responsible person.

| Person | Responsibility | Deliverables |
|---|---|---|
| Aditya | 3D Assets & Environment — create interactive 3D models and scenes | Kitchen, bedroom, medicine bottles, groceries, furniture, hand-interactable objects |
| Brian | UX/UI & Spatial Design — design the user experience and guidance | Menus, onboarding, arrows, highlights, prompts, progress indicators, accessibility, interaction flow |
| JingTong | Apple Vision Pro Development — build the application in RealityKit/SwiftUI | Scene setup, object interactions, hand tracking, gaze input, game logic, scoring, data storage |
| Nicole | Clinical Research & Content — ensure exercises are evidence-based | Research dementia rehabilitation, design cognitive exercises, validate task difficulty, define success metrics |
| Basil | AI, Analytics & Integration — personalization and progress tracking | Adaptive difficulty, performance metrics, therapist dashboard, data visualization, presentation/demo support |

## Skills layout (not two copies)

This is a **visionOS / Apple Vision Pro** project (SwiftUI + RealityKit + ARKit).

| Path | Role |
| --- | --- |
| **`.skills/`** | **Canonical skill store** — real files on disk |
| **`.agents/skills`** | **Symlink** → `../.skills` (harness discovery only) |

`.agents/skills` and `.skills` resolve to the **same directory**. Do **not** maintain a second copy under `.agents/`. If a path looks duplicated in listings, it is the symlink, not drift.

```text
.skills/                  ← real skill pack
.agents/
  skills -> ../.skills    ← discovery alias for agents that look under .agents/skills
```

Provenance / how to refresh visionOS skills: `.skills/SOURCE.md`.  
Persona + routing overview: `.skills/VISIONOS_AGENTS.md`.

## Skills (required for quality code)

Regardless of which AI product or harness you are, you **must**:

1. Treat **`.skills/`** as the single source of truth (or the same content via `.agents/skills/`).
2. **Before writing or refactoring** any Swift, SwiftUI, RealityKit, ARKit, USD, ShaderGraph, or spatial UI code, open the matching skill at `.skills/<skill-name>/SKILL.md` (and its `references/` when relevant) and follow it.
3. Do **not** improvise platform APIs from model memory when a skill covers the task.
4. For Swift changes, also apply `.skills/coding-standards-enforcer/SKILL.md`.

### Process skills — mattpocock pack (full install)

Full set from [mattpocock/skills](https://github.com/mattpocock/skills) lives under `.skills/` (engineering + productivity + misc + in-progress). Inventory + refresh: `.skills/SOURCE.md`.

**Once per repo**, run **`/setup-matt-pocock-skills`** (issue tracker, triage labels, domain-doc paths).

#### Core loop (use often)

| Skill | Use when |
| --- | --- |
| **`/grill-me`** | Align on a plan/design before coding (runs **`/grilling`**) |
| **`/grill-with-docs`** | Same grill, plus domain model / `CONTEXT.md` / ADRs |
| **`/tdd`** | Red–green–refactor implementation |
| **`/implement`** | Build from a spec/tickets with TDD + code-review |
| **`/to-spec`** | Turn the current conversation into a published spec |
| **`/to-tickets`** | Break a plan into tracer-bullet tickets |
| **`/code-review`** | Standards + spec review of a diff |
| **`/diagnosing-bugs`** | Hard bugs / performance regressions |
| **`/ask-matt`** | Unsure which skill fits — router over the pack |
| **`/handoff`** | Compact session for another agent |
| **`/improve-codebase-architecture`** | Survey deepening opportunities |
| **`/wayfinder`**, **`/triage`**, **`/wizard`**, **`/prototype`**, **`/research`**, **`/domain-modeling`**, **`/codebase-design`**, **`/resolving-merge-conflicts`**, **`/teach`**, **`/wait-what`**, **`/to-questionnaire`**, **`/writing-for-agents`** | See each skill’s `SKILL.md` |

Misc (`setup-pre-commit`, `git-guardrails-claude-code`, …) and **in-progress** skills (`loop-me`, `writing-*`, …) are also installed; treat in-progress as experimental.

During a grill: frontier-round questions, recommend answers, look up facts yourself, **do not implement** until the user confirms shared understanding.

### Platform skill map (visionOS)

| Skill directory under `.skills/` | Load when |
| --- | --- |
| `spatial-app-architecture` | Window vs volume vs immersive space, scene boundaries, state ownership, file layout — **first** for structure |
| `spatial-swiftui-developer` | SwiftUI scenes, `RealityView`, `Model3D`, attachments, volumes, `ImmersiveSpace`, spatial gestures |
| `realitykit-visionos-developer` | Entities/components, scene setup, assets, input, attachments, portals (router to focused RealityKit skills) |
| `realitykit-ecs-systems` | Custom components, systems, ECS queries, multi-entity per-frame behavior |
| `realitykit-rendering-materials` | Materials, lighting, cameras, VFX, render cost |
| `realitykit-animation-physics` | Animation, physics, collision, particles, character motion |
| `realitykit-audio-spatial` | Spatial / ambient audio on entities |
| `arkit-visionos-developer` | ARKit session, authorization, provider selection (router) |
| `arkit-hand-tracking-provider` | Hand anchors, joints, hand-driven interaction |
| `arkit-spatial-tracking-providers` | World / plane / room / scene reconstruction |
| `arkit-camera-access-providers` | Camera frame / region providers |
| `arkit-reference-tracking-providers` | Image / object / barcode / accessory tracking |
| `arkit-rendering-context-providers` | Environment light, stereo, visual fidelity |
| `coding-standards-enforcer` | Any Swift write or review (Swift 6 concurrency, isolation, modern APIs) |
| `shadergraph-editor` | Shader Graph / `.usda` materials |
| `usd-editor` | Hand-edited USD / USDZ pipeline |
| `usdkit-runtime-developer` | Runtime USDKit / stage editing |
| `shareplay-developer` | GroupActivities / SharePlay |
| `visionos-widgetkit-developer` | visionOS widgets |
| `visionos-immersive-media-developer` | Immersive / spatial video |
| `swiftui-chart3d-developer` | Chart3D / 3D charts |

### Workflow

1. Restate the goal.
2. If the plan or design is still fuzzy, run **`/grill-me`** or **`/grill-with-docs`** before coding.
3. Prefer mattpocock process skills for planning, TDD, tickets, and review (`/to-spec`, `/to-tickets`, `/tdd`, `/implement`, `/code-review`).
4. Pick visionOS platform skill(s) from the table above for any Swift / RealityKit / ARKit work.
5. Read `.skills/<name>/SKILL.md` (and needed `references/`).
6. Implement in small steps; re-check Swift with `coding-standards-enforcer`.
7. Update `CHANGELOG.md` for any file writes (see below).

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
