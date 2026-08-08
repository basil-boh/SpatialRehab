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

## Battery (v1 draft, 4 games)

| # | Game | Format | Captured |
|---|------|--------|----------|
| 1 | Word memory | Study ~6 target words for ~10s, then tap all remembered words from a shuffled target+distractor grid | `targetWords`, `distractorWords`, `tappedWords`, `completedAt`; score computed as correct-taps / targets |
| 2 | Pattern matching | Classic memory-flip: 6 pairs of symbol cards, flip two at a time to find matches | `pairCount`, `moveCount`, `completedAt`; score computed as pairs / moves (efficiency, not correctness) |
| 3 | Arithmetic | Basic single-digit addition, tap the correct sum from 4 choices, one problem at a time | Per-problem `ArithmeticAnswer` (prompt, correct answer, selected answer), `completedAt`; score computed as correct / total |
| 4 | Clock drawing | Free-draw prompt: "Draw a clock showing ten past eleven." | Rasterized PNG (`imageFileName`), `capturedAt`; `score` left `nil` for later review |

Word list, distractor set, study duration (`BaselineAssessmentContent.WordMemory`), the
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

## Known gaps (intentional, for a first prototype)

- No automated clock-drawing scoring — see above. Only the rasterized PNG is kept, not
  stroke/vector data; a future auto-scorer wanting stroke-angle analysis would need a
  different capture design than this one.
- No persistence beyond local `UserDefaults` (`BaselineResultsStore`) — no export, backup,
  or sync. Uninstalling the app loses all baseline data, including saved clock PNGs on disk.
  No cleanup of orphaned image files if the first-launch flag is ever manually reset for QA.
- No recommendation engine — using the baseline to personalize later exercises (the
  original motivation for capturing it at all) is explicitly out of scope for this task.
- No caregiver-facing review UI yet for the unscored clock drawings — expected to land with
  the `feature/analytics` dashboard.
- No automated tests — this repo has no test target; verification is manual/Simulator-based,
  same as the tea-task prototype.

These are reasonable next slices, not oversights — flagging them explicitly so the next
change knows where the seams are.
