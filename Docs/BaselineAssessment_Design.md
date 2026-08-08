# Task design: Baseline Metric assessment

First-launch cognitive baseline battery for the Vision Pro app. Drafted as a first pass using
standard dementia-care assessment concepts (clock-drawing test, word-recognition memory
test) — **not** clinically reviewed yet. Revise word list, distractor strategy, study
duration, and any future scoring scale with clinical input (Nicole, per `AGENTS.md`) before
using with real patients.

## Design principles applied

- **Errorless learning, applied to assessment** — an assessment is inherently about
  measuring correctness, which is in tension with "never let the person feel they got it
  wrong." Resolved by never surfacing scores or right/wrong feedback to the patient
  anywhere in the flow (`BaselineAssessmentView` shows no tally; `WordMemoryGameView`'s tap
  grid only shows neutral "selected" state, never color-coded correct/incorrect). Scoring
  happens silently, for later caregiver/clinician review, not as in-the-moment feedback to
  the patient.
- **Recognition over recall** — the word-memory test uses a tap-a-grid recognition format
  rather than typed/spoken free recall. Chosen for two reasons: (1) visionOS on-screen
  keyboard input is high-friction for this audience, and scoring free text against
  typos/synonyms is unreliable; (2) it fits the same large-tap-target, no-typing interaction
  style already used for `Done`/`Back`/`Skip` in `GuidanceCardView`. Trade-off: recognition
  inherently shows several word options on screen at once (it needs distractors to be
  meaningful), which is a deliberate, scope-confirmed exception to this app's usual
  one-decision-at-a-time screens elsewhere.
- **Clock-drawing test is intentionally unscored** — real clock-drawing scoring (numeral
  placement, hand-length/angle proportions, etc.) is a genuine clinical-scoring problem.
  Rather than fake it with an unvalidated heuristic, v1 captures only the rasterized sketch
  (`ClockDrawingResult.score` stays `nil`) for a caregiver to review later. This is expected
  to connect to the caregiver dashboard being built on `feature/analytics` (not yet merged
  into `main`) once that work lands.
- **Free retry, no penalty** — the clock-drawing canvas has an unconditional "Clear" button;
  redrawing costs nothing and isn't tracked as a failed attempt.
- **Intended as first-launch-only, not a recurring gate** — the battery is meant to
  establish one starting point, not to be repeated every launch. The gate lives in
  `SpatialRehabApp`, switching the shared `WindowGroup` body between the assessment and the
  existing welcome/tea-task flow. **Temporarily set to run on every launch** (plain
  `@State`, not persisted) while the battery is under active development, so each run is
  easy to see/test; swap back to `@AppStorage("baseline.hasCompletedBaseline")` once the
  battery is stable — see the comment on `SpatialRehabApp.hasCompletedBaseline`.

## Battery (v2, 8 games)

Order: reaction time (warm-up) → orientation → word memory → digit span → pattern matching
→ trail making → arithmetic → clock drawing. Related domains are grouped adjacently
(memory games together, executive-function games together) rather than an arbitrary
sequence; the battery opens with a literal warm-up and closes with the free-form drawing
task.

| # | Game | Format | Captured |
|---|------|--------|----------|
| 1 | Reaction time | A shape flashes at a random position after a random delay, tap it, 3 trials | `reactionTimesMs`, `completedAt`; no `0...1` score — raw ms readings, like clock drawing this isn't forced into a percentage |
| 2 | Orientation | 3 questions (day of week / time of day / month), computed from the current date, tap the answer from a few choices | Per-question `OrientationAnswer`, `completedAt`; score = correct / total |
| 3 | Word memory | Study ~4 target words for ~10s, then tap all remembered words from a shuffled target+distractor grid (10 total) | `targetWords`, `distractorWords`, `tappedWords`, `completedAt`; score computed as correct-taps / targets |
| 4 | Digit span | Watch a 4-digit sequence flash one digit at a time, then tap it back in order on a number pad | `targetSequence`, `enteredSequence`, `completedAt`; score = correctly-placed digits / sequence length |
| 5 | Pattern matching | Classic memory-flip: 6 pairs of symbol cards, flip two at a time to find matches | `pairCount`, `moveCount`, `completedAt`; score computed as pairs / moves (efficiency, not correctness) |
| 6 | Trail making | Tap 8 scattered, numbered dots in ascending order | `dotCount`, `errorCount`, `durationSeconds`, `completedAt`; score = dots / (dots + errors); duration captured but not scored — no visible time pressure |
| 7 | Arithmetic | Basic single-digit addition, tap the correct sum from 4 choices, one problem at a time | Per-problem `ArithmeticAnswer` (prompt, correct answer, selected answer), `completedAt`; score computed as correct / total |
| 8 | Clock drawing | Free-draw prompt: "Draw a clock showing ten past eleven." | Rasterized PNG (`imageFileName`), `capturedAt`; `score` left `nil` for later review |

None of the four new games (reaction time, orientation, digit span, trail making) feed
`GameRecommendationEngine` — `CognitiveDomain` stays at its original three cases
(`.memory`/`.numeracy`/`.executiveFunction`) rather than growing new ones or merging a
second game's score into an existing domain, which would need a real policy decision
(average? most recent? which wins?) that wasn't asked for. Deliberately out of scope for
this pass, not an oversight.

Word list is **4 target words + 6 distractors** (10 in the recall grid), tuned on 2026-08-08:
started at 6+6, briefly tried 4+4, then settled on 4+6 — a shorter study list than the
original but the same distractor pressure. Word list, distractor
set, study duration (`BaselineAssessmentContent.WordMemory`), the
pattern-matching symbol set, and the arithmetic problem list are placeholders, not validated
for difficulty (e.g. whether word distractors should be semantically related to targets,
which materially changes test difficulty; or whether the arithmetic problems are calibrated
to the "basic mental sums" bar from the product brief).

Pattern matching and arithmetic diversify the battery's cognitive domains beyond memory
(word recall, clock drawing already lean on memory/visuospatial): matching-pairs adds a
working-memory + attention-efficiency signal (moves-to-completion), arithmetic adds a basic
numeracy signal. Neither is scored as pass/fail to the patient — pattern-matching mismatches
just flip back calmly (no penalty, no color-coded "wrong"), and arithmetic taps advance
immediately with no visible correctness feedback, matching the no-punishment principle above.

### Light audio/visual feedback (2026-08-08 addition)

Word memory, pattern matching, and arithmetic all use a shared `SoundEffects` helper
(`AudioServicesPlaySystemSound`, deliberately soft/short — no celebratory fanfare, no
startling sounds) for tap/match feedback, plus a small scale-bounce animation on selection.

- **Colors and sounds are assigned by identity, never correctness.** The tap sound plays on
  every selection uniformly. Word-memory selection is never color-coded by correctness —
  this was checked deliberately against the no-punishment principle above before shipping.
- **System sound IDs are an informal API** — Apple doesn't officially document a stable
  ID-to-sound mapping across OS versions. Fine for a hackathon build; a production pass
  should bundle short custom audio assets instead.

### Word-memory refinements (2026-08-08, second pass)

After the first colorful pass above, the word-memory game was simplified based on direct
feedback:

- **Visible study countdown** — the study screen now shows a live number + progress bar
  counting down the `studyDurationSeconds` window, instead of silently timing out. Makes the
  "how long do I have" state legible rather than implicit.
- **Green-only highlight** — the per-word pastel color tint was removed. Selected
  ("remembered") words are now shown in a single color, green; unselected words are neutral
  gray. One consistent highlight color reads more clearly as "this is picked" than a
  different color per word did, and is simpler for this audience to parse at a glance.
- **Softer selection sound** — word taps use a new `SoundEffects.playSoftTap()` (a lighter
  system sound than the shared `playTap()` used by pattern-matching/arithmetic), since word
  selections happen more rapidly/repeatedly than the other games' taps.

### Dev-only results view, AR task disabled for now (2026-08-08)

`ContentView` (reached after the battery finishes) previously opened the AR "Making Tea"
guided task via its "Get Started" button. That's disabled while baseline-metrics is the
active focus — the button now opens `BaselineResultsDebugView` instead, a raw dump of
everything `BaselineResultsStore` has captured (word lists, tapped words, pattern-matching
move count, arithmetic per-problem answers, the clock-drawing timestamp and saved sketch
image itself). This is explicitly a **developer tool**, not a caregiver-facing feature —
the patient-facing summary screen at the end of the battery still shows no score at all,
unchanged from the no-punishment principle above. `SpatialRehabApp` still declares the
`ImmersiveSpace` scene and owns `teaSession`; the AR task's source files are untouched, just
not entered from this screen right now, so re-enabling it later is a small, localized change
in `ContentView.swift`.

### Game recommendation engine (2026-08-08)

`GameRecommendationEngine` (`SpatialRehab/Models/`) ranks cognitive-stimulation games by
which measured domain is currently weakest, closing the "no recommendation engine" gap
noted below. Scope is deliberately narrow — this is the ranking logic only; wiring it into
an actual session-selection UI is left for a teammate to build on top:

- **Three domains, not four** — `CognitiveDomain` covers `.memory` (word memory),
  `.numeracy` (arithmetic), and `.executiveFunction` (pattern matching), the three trials
  that produce an automatic `score`. Clock drawing has no case here — it stays unscored
  until a caregiver reviews it (see above), so there is no automatic reading to rank it
  with; it simply never appears in a recommendation rather than being defaulted to 0 and
  incorrectly treated as the weakest domain.
- **Weighted comparison, not a trained model** — a single patient produces at most a
  handful of readings per domain, nowhere near enough to fit anything meaningful, and a
  caregiver needs to be able to see *why* a domain was picked. `priority = 1 - score`,
  sorted descending, is the entire ranking rule.
- **`StimulationGame`/`StimulationGameCatalog`** hold the games each domain maps to
  (titles drawn from the product-vision doc's ability→exercise table); these are metadata
  only, not built game views.
- **`BaselineResultsStore.currentDomainScores()`** bridges the existing store's three
  scored trials into the engine's input shape without modifying `BaselineResultsStore`
  itself. `GameRecommendationEngine.currentRecommendations()` is the one-call entry point
  a teammate wiring this into UI would use; `recommendations(from:)` stays a pure function
  for when this repo eventually gets a test target.

**Wired into `BaselineResultsDebugView` (2026-08-08, same day)** — a "Recommended Focus
(Dev)" section shows each domain's priority as a bar (reusing that domain's game's
identity color for visual continuity with the score gauges above) plus the top-priority
domain's recommended games. Deliberately kept dev-only: `StimulationGameCatalog`'s games
aren't real, tappable screens yet, so surfacing them to the *patient* would recommend
something broken. Promote this to the patient-facing summary once those games are built —
at that point, frame it as a forward-looking suggestion only ("let's try X next"), never
with the underlying priority/score number, to stay consistent with the no-score-to-patient
principle above.

## History tracking + caregiver dashboard (2026-08-08)

`BaselineResultsStore` switched from single-overwritten-value storage to an **appended
history array** per game — the previous version silently discarded a session's data the
moment the next session finished, which undercut the entire premise of a comparison
baseline. `loadXResult()` accessors still work (return the latest entry, `.last`), so no
existing call site broke; new `loadXHistory()` accessors return the full run.

`CaregiverDashboardView` is the payoff: a real, polished caregiver-facing screen (not a dev
tool) showing a `ScoreTrendChart`/`MillisecondTrendChart` line chart per game across
sessions, plus a clock-drawing thumbnail gallery (still unscored, but now at least browsable
over time instead of only the latest sketch). `ContentView`'s primary action now opens this
dashboard directly; the raw `BaselineResultsDebugView` dump moved one level deeper, behind a
"Raw Data" toolbar button inside the dashboard, since the dashboard is what a caregiver
should actually land on.

**Migration caveat:** results saved before this change were single encoded values, not
arrays — decoding old data as `[T]` fails silently (returns `[]`), so any pre-existing
single-entry test data doesn't carry forward into the new history. Acceptable for local
hackathon test data; a real migration would need to attempt both decode shapes.

## Known gaps (intentional, for a first prototype)

- No automated clock-drawing scoring — see above. Only the rasterized PNG is kept, not
  stroke/vector data; a future auto-scorer wanting stroke-angle analysis would need a
  different capture design than this one. The caregiver dashboard's gallery makes the
  sketches browsable over time, but scoring is still entirely manual/visual.
- Still no export/backup/sync (`UserDefaults` only) — uninstalling the app loses all
  baseline history, including saved clock PNGs on disk. No cleanup of orphaned image files
  if the first-launch flag is ever manually reset for QA.
- No automated tests — this repo has no test target; verification is manual/Simulator-based,
  same as the tea-task prototype. The dashboard specifically was verified by temporarily
  seeding synthetic multi-session data (see git history/CHANGELOG), not real gameplay, since
  this sandbox has no way to interactively tap through the games.

These are reasonable next slices, not oversights — flagging them explicitly so the next
change knows where the seams are.
