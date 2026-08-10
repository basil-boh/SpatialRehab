# Task design: Daily Practice hub

Expands the four baseline-battery mini-games (word memory, pattern matching, arithmetic,
clock drawing) into a **separate, repeatable** practice area with levels, adaptive
difficulty, in-round progress bars, and per-game daily tracking. Drafted as a first pass —
**not** clinically reviewed. Revise difficulty curves and word/problem content with clinical
input (Nicole, per `AGENTS.md`) before using with real patients.

## Why a separate hub, not a repeatable baseline

`BaselineAssessmentSession`/`BaselineAssessmentView` stay exactly as designed: a **one-time
starting-point measurement**, run once (currently every launch, temporarily, per the existing
"known gaps" note — see `BaselineAssessment_Design.md`). Turning that same flow into the daily
thing would blur "one fixed measurement to compare against later" with "ongoing therapy
session," which are different purposes with different content-stability needs (a baseline
must stay comparable over time; daily practice should vary and escalate). `DailyPracticeHubView`
is new, additive, and does not change baseline behavior — the four existing game views
(`WordMemoryGameView`, `PatternMatchingGameView`, `ArithmeticGameView`, `ClockDrawingView`)
are reused via new **optional, default-valued** parameters, so every existing baseline call
site behaves byte-for-byte the same as before.

**Revisiting the baseline from the hub (2026-08-10):** the battery was previously reachable
*only* as `SpatialRehabApp`'s mandatory first-launch gate, with no way to intentionally retake
it later. `DailyPracticeHubView` now has a top-left "Baseline Quiz" button (mirroring the
top-right calendar button) that presents `BaselineAssessmentView` in a sheet with a **fresh
`BaselineAssessmentSession` per presentation** — recreated on dismiss, since the session type
deliberately has no `reset()`/`goBack()` (see its own doc comment), so a new instance is the
correct way to make it restart at `.intro` rather than resume wherever a previous attempt
left off. This doesn't change the "one-time starting-point measurement" framing above — it's
still the same fixed, comparable battery — it's just no longer gated to exactly once per app
lifetime; a caregiver can walk through it again as a deliberate "step 1" whenever they want.

## The core design tension, and how it's resolved

The baseline design doc's hardest rule — "never surface scores or right/wrong feedback to
the patient" — is in real tension with "levels and difficulty that feel like a real game."
A naive implementation ("Level 3, you scored 60%") is exactly the kind of grading this app
has deliberately avoided everywhere else. Resolved by splitting **what the patient sees**
from **what silently drives difficulty**:

- **Visible level** (`GameProgress.visibleLevel`) — a plain session counter. It goes up by
  exactly 1 every time a round is completed, **regardless of performance**, forever. It never
  decreases, never stalls, and is never computed from a score. This is the "real game" feeling
  the product ask wants (a rising stage number is inherently positive), with zero risk of it
  reading as a grade — it literally cannot go down.
- **Difficulty level** (`GameProgress.difficultyLevel`, 1–30 — widened from an initial 1–5,
  see revision note below) — the thing that actually changes what's asked of the patient
  (word count, pair count, arithmetic complexity). It *does* adapt from performance (reusing
  each result type's existing, already-computed `score`, e.g. `WordMemoryTrial.score`), per
  the product's explicit choice to make this adaptive rather than a flat always-forward curve.
  It's never spoken of as "difficulty" in the UI and the exact number is never printed as
  text — but unlike the first pass, it **is** shown visually now, as the tile's dot grid
  (filled dots = current level out of 30). Showing *some* visual signal for it was an explicit
  product ask ("progress dots... to represent each level"); a filled-dot grid is closer to a
  game's level-progress bar than a literal "Difficulty: 14/30" label would be, so it stays
  consistent with "never show a number that reads as a grade."

Net effect: the number the patient sees only ever climbs ("Level 12!"), while the actual
challenge quietly calibrates so they're neither bored nor frustrated. Both halves of the
product ask — "real game with levels" and "adaptive difficulty" — are satisfied without
reintroducing visible scoring.

### Difficulty rule: gradual schedule + performance nudge (revised 2026-08-09)

The first pass adapted difficulty from `score` alone (≥0.8 up a level, ≤0.4 down a level,
otherwise unchanged). That had a real gap: most rounds land in the middle band, which left
difficulty completely flat — someone could finish a dozen rounds and still be on level 1,
which reads as "the levels aren't actually getting harder." Revised to two components:

1. **Gradual schedule** — `difficultyLevel` has a floor tied to `visibleLevel`:
   `min(30, visibleLevel)`. Reaches the max level (30) around visible level 30 at the
   baseline pace regardless of performance. **Was `1 + (visibleLevel-1)/3` (one step every 3
   rounds) until 2026-08-09** — that paced fine on paper but on a 30-dot grid it read as "the
   dots aren't moving" during any normal testing session, since 2 of every 3 rounds produced
   zero visible change. Tightened to advance every single round by default so progress is
   always visible round to round; performance can still pull ahead or hold back on top of
   that baseline.
2. **Performance nudge**, layered on top of the schedule, using that round's `score`
   (0.0–1.0, already computed by the existing result types — no new scoring logic needed):
   `score >= 0.8` → pulls one level ahead of the schedule (capped at 30); `score <= 0.4` →
   eases back one level from wherever it currently is (floored at 1), overriding the schedule
   for that round; otherwise → at least keeps pace with the schedule, never regresses below it.

Still intentionally simple, not a real adaptive-difficulty algorithm — that's teammate
Basil's roadmap item per `AGENTS.md` ("Adaptive difficulty, performance metrics"). This rule
is a placeholder that satisfies "feels like it's actually getting harder" for a hackathon
demo; it should very plausibly be replaced wholesale once Basil's analytics work lands,
without needing to change anything about the visible-level/hidden-tier split above.

### Draw & Trace: no difficulty tier, but real depth via subject count + vanishing cues (revised 2026-08-09)

Clock drawing keeps the baseline doc's existing reasoning: there's no well-defined "harder
clock" at this scope, and it's deliberately unscored (no `score` to adapt from), so it has no
`difficultyLevel`. It still gets a `visibleLevel` (so every game in the hub feels consistent
— "Level 6" — and keeps climbing).

**Its tile still gets a 30-dot grid** (added 2026-08-09) — leaving it as the one tile with no
visual progress indicator at all was itself a gap once every other tile had one. Rather than
faking a difficulty number it doesn't have, the dots represent something else that's real and
already bounded at 30: `GameProgress.visitedDrawingSubjectIDs`, a permanent "collected" mark
per subject (dot fills the first time that subject is drawn, stays filled forever after —
never un-fills, same one-directional-progress rule as everything else here).

What *does* change with level is the subject (`DrawingSubject`, `DrawingSubjects.swift`).
Level 1 is always the clock — free-recall from a text prompt, no reference shown, unchanged
from the original Clock Drawing Test. Every level after cycles through a fixed list of common
animals and everyday objects, each shown as a traceable SF Symbol outline behind the canvas
rather than asked for from pure memory. This was a deliberate mechanic change for these
subjects, not just a prompt swap: pure free-recall drawing is harder and more error-prone for
this population, while tracing a shown outline is lower-frustration and still exercises the
intended goal — the product ask was explicitly to "jog their memory for common items," which
naming/recognizing a traced shape does more reliably than blind recall would.
`ClockDrawingResult.subjectID` records which subject was drawn (defaults to `"clock"`, so the
baseline call site is unaffected) so a later reviewer knows what they're looking at.

**Originally 11 subjects total, expanded to 30** (matching the 1–30 scale the other three
games use) — the small list was a real gap: it was the only one of the four games with no
sense of growing depth over time, cycling through the same 10 objects almost immediately.

That still leaves the *content itself* just as easy forever on repeat cycles, since tracing
the same outline doesn't get harder by definition. Added a second axis instead of pretending
otherwise: **outline fading**, based on the "vanishing cues" technique from dementia memory
care — start with a clear prompt, then gradually withdraw it as the response strengthens,
rather than making the shape itself harder (`DrawingSubjects.outlineOpacity(forLevel:)`).
Opacity starts at 0.25 (unchanged from the original fixed value) on the first pass through all
29 objects (levels 2–30), fades by 0.05 on each subsequent full pass, floored at 0.06 — never
literally invisible, so tracing stays achievable rather than becoming a surprise recall test.
`ClockDrawingView` itself stays unaware of "levels" or fading logic — it just renders whatever
`outlineOpacity` value it's given, same separation of concerns as its `subject` parameter.

Symbol names were verified against the installed visionOS 27 SDK before use (compiled and ran
a small check inside the Simulator; `UIImage(systemName:) != nil` for every candidate) rather
than assumed from memory — `flower.fill`, `butterfly.fill`, and `spoon.fill` don't exist in
this SDK and were dropped from consideration.

## Content scaling (levels 1–30, placeholders — not clinically reviewed)

Widened from an initial 1–5 scale (2026-08-09) so the climb feels like sustained progress
over weeks of daily play rather than something maxed out in a handful of sessions — see the
revised difficulty rule below for pacing. Formulas, not a fixed table (`PracticeDifficulty.swift`):

| Game | Level 1 | Formula | Capped at |
|---|---|---|---|
| Word memory | 4 words, 15s study | words: `min(9, 4 + (level-1)/5)`; study: `max(5, 15 - (level-1)/2)`s | 9 words, 5s |
| Pattern matching | 3 pairs (6 cards) | `min(12, 3 + (level-1)/3)` pairs | 12 pairs (the symbol pool size) |
| Arithmetic | addition, 1–6, 4 problems | range: `1...min(50, 4 + level*2)`; problems: `min(8, 4 + (level-1)/6)`; subtraction from level 6 | range 1–50, 8 problems |
| Draw & Trace | same free-recall clock at every level — see below | | |

Word memory's 22-word bank and pattern matching's 12-symbol pool are both sized with margin
above their respective caps (9+9=18 words needed vs. 22 available; 12 pairs needed vs. 12
symbols available — the pool is the hard ceiling on pairs, which is why pairs cap there).

Word memory and arithmetic content is **procedurally drawn/generated each round** (a larger
word bank sampled per round; arithmetic problems generated within the tier's number range)
rather than a fixed table, unlike the baseline's fixed lists. This is deliberate: a *daily*
game repeating the exact same words/problems forever would get memorized rather than
practiced, which both dulls the cognitive-training value and makes the app boring to return
to — directly against the "come back and enjoy it" goal. The baseline battery's fixed lists
stay fixed on purpose (comparability); practice content stays varied on purpose (replay
value).

## Daily tracking: a separate calendar tab (revised 2026-08-09)

Originally a 7-dot streak row on each hub tile. Moved to its own screen
(`PracticeCalendarView`, reached via a corner calendar button on `DailyPracticeHubView`) once
the hub tiles' dot grid was repurposed to show difficulty level instead (see above) — trying
to show both day-history *and* difficulty on the same small tile was too dense to read at a
glance, and day-history is inherently a "look back over time" activity that fits a dedicated
screen better than a tile corner.

`PracticeProgressStore` still keeps a `Set<String>` of `"yyyy-MM-dd"` day-strings **per game
type** marking any day that game was completed at least once — per the product ask for
tracking "for each style of task," not just one combined number. `PracticeCalendarView`
presents this three ways:

- **Month calendar** — a familiar month-grid (not GitHub's week-column heatmap shape, which
  is a less immediately readable layout for this audience even though it's the same
  "green dot on days you did something" idea) built from the **union** of all four games'
  day-sets, so it answers "did I do anything that day," computed on the fly rather than
  double-written to avoid it drifting out of sync with the per-game data.
- **Current streak** — a Duolingo-style flame + "N days in a row" count
  (`PracticeProgressStore.currentStreak(dayStrings:)`). An in-progress streak still counts
  through yesterday if today hasn't happened yet — it shouldn't read as "broken" just because
  it's still early in the day. A missed day quietly resets it to 0 with no "you broke your
  streak" messaging anywhere.
- **Badges** — permanent achievements (7-day, 30-day), which is *not* the same number as the
  live streak: a badge stays earned even after a later missed day resets the current streak
  back to 0, matching how Duolingo/habit apps treat badges as history, not live state. Tracked
  separately (`PracticeProgressStore.longestCombinedStreak()`, a persisted high-water mark)
  rather than derived from the current streak for exactly that reason.
- **Per-game breakdown** — a plain list of each game's own current streak, satisfying "for
  each style of task" without needing four separate full calendars.

`DailyPracticeHubView`'s header no longer shows the old "X of 4 today" summary line — that
information now lives on the calendar screen instead of being duplicated on the hub.

## In-round progress bars

Every game now shows some form of round-progress, extending the pattern
`WordMemoryGameView`'s study countdown already established:

- Word memory: existing countdown bar (unchanged).
- Pattern matching: added a `found / total pairs` bar directly to `PatternMatchingGameView`
  itself, next to the existing title, rather than plumbing progress out through a callback —
  it's neutral positional information (not a correctness signal), so it's a free improvement
  for the baseline flow too, not something that needed to be practice-only.
- Arithmetic: same reasoning — added a bar next to the existing "Problem N of total" text
  directly in `ArithmeticGameView`, benefiting both baseline and practice.
- Clock drawing: no natural "progress" metric for a single free-draw canvas; omitted rather
  than faked.

## Known gaps (intentional, for a first pass)

- The adaptive rule is a 3-bucket placeholder, explicitly expected to be replaced by Basil's
  real adaptive-difficulty work — see above.
- No cross-device sync — `PracticeProgressStore` is local `UserDefaults`, same limitation as
  `BaselineResultsStore`. Progress/streaks are per-device, lost on uninstall.
- No caregiver-facing view of practice history yet — expected to connect to the
  `feature/analytics` dashboard once merged, same as baseline results.
- Difficulty curves and generated-content ranges (word bank, arithmetic number ranges) are
  placeholders, not validated for this population — flagged the same way
  `BaselineAssessment_Design.md` flags its own content.
- No tests — same manual/Simulator-verification approach as the rest of this repo.
- Repeated daily clock-drawing rounds each save a new PNG to the Documents directory (same
  `ClockDrawingView.saveDrawing()` used by the one-time baseline) with no cleanup — over many
  days of practice this accumulates files with no expiry/pruning. Fine for a hackathon demo;
  a real deployment needs a retention policy or a cap on saved sketches per game.
