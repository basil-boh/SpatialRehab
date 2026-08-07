# Skills in this repo

Canonical location: **`.skills/`** (repo root).

Harness discovery (no duplicate content):

- `.agents/skills` → symlink to `../.skills`

All coding agents — Grok, Claude, Cursor, Codex, or anything else — load skills
from this folder. See root `AGENTS.md` / `CLAUDE.md`.

## Packs

| Pack | Source | Notes |
| --- | --- | --- |
| **visionOS platform** | https://github.com/tomkrikorian/visionOSAgents | RealityKit, ARKit, spatial SwiftUI, USD, SharePlay, etc. |
| **mattpocock process** | https://github.com/mattpocock/skills | Engineering + productivity + misc + in-progress |

Installed mattpocock snapshot: commit `84fdeff` (shallow clone; refresh with steps below).

## Skill inventory (high level)

### visionOS (tomkrikorian)

`spatial-*`, `realitykit-*`, `arkit-*`, `coding-standards-enforcer`, `shadergraph-editor`, `usd-*`, `shareplay-developer`, `visionos-*`, `swiftui-chart3d-developer`, `tkr-skill-writer`

### mattpocock — engineering

`ask-matt`, `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grill-with-docs`, `implement`, `improve-codebase-architecture`, `prototype`, `research`, `resolving-merge-conflicts`, `setup-matt-pocock-skills`, `tdd`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `wizard`

### mattpocock — productivity

`grill-me`, `grilling`, `handoff`, `teach`, `to-questionnaire`, `wait-what`, `writing-for-agents`

### mattpocock — misc

`git-guardrails-claude-code`, `migrate-to-shoehorn`, `scaffold-exercises`, `setup-pre-commit`

### mattpocock — in-progress (experimental)

`claude-handoff`, `loop-me`, `setup-ts-deep-modules`, `writing-beats`, `writing-fragments`, `writing-shape`

## First-time setup for mattpocock engineering flow

In the agent, run once per repo:

```text
/setup-matt-pocock-skills
```

It configures issue tracker, triage labels, and where domain docs / ADRs live.

## Refresh visionOS skills

```bash
git clone --depth 1 https://github.com/tomkrikorian/visionOSAgents.git /tmp/visionOSAgents
# Do NOT use --delete — that would wipe mattpocock skills
rsync -a /tmp/visionOSAgents/skills/ .skills/
cp /tmp/visionOSAgents/AGENTS/AGENTS.MD .skills/VISIONOS_AGENTS.md
```

## Refresh mattpocock skills (all stable + misc + in-progress)

```bash
git clone --depth 1 https://github.com/mattpocock/skills.git /tmp/mattpocock-skills
for cat in engineering productivity misc in-progress; do
  for d in /tmp/mattpocock-skills/skills/$cat/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name=$(basename "$d")
    rm -rf ".skills/$name"
    cp -R "$d" ".skills/$name"
  done
done
# Update the commit SHA note in this file after refresh.
```

Or use the interactive installer (picks agent discovery paths):

```bash
npx skills@latest add mattpocock/skills
```

Prefer the scripted copy above for this repo so everything lands under **`.skills/`** and stays visible via `.agents/skills`.
