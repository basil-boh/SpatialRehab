# Task design: "Making a Cup of Tea"

First content prototype for the Vision Pro guided-ADL (activity of daily living) experience.
Drafted as a first pass using standard dementia-care task-analysis principles — **not**
clinically reviewed yet. Revise with OT/clinical input before using with real patients.

## Design principles applied

- **Errorless learning** — the app should prevent mistakes rather than correct them after
  the fact. Only the current step's target is highlighted; future objects stay hidden/dim
  so the person is never shown something they're not ready to act on yet.
- **Minimal choices** — one action per step, described as a single imperative sentence.
  No branching decisions except explicitly-marked optional steps (e.g. milk/sugar), which
  are skippable with one tap rather than presented as a question.
- **Consistent single-step cueing** — each step ships an `instructionText` (short, present
  tense, one verb) and a `spokenCue` (same content, phrased for audio/VoiceOver) so the cue
  is always available in both text and speech without extra authoring later.
- **Low working-memory load** — progress shown as dots (○●○○), not "step 3 of 7", since
  arithmetic/ordinal tracking is itself a burden for some users.
- **Escalating prompt levels reserved, not yet implemented** — `TaskStep` carries a
  `promptLevel`-ready shape (see `Models/TaskStep.swift`) so a later version can escalate
  from ambient highlight → pulsing highlight → spoken repeat → caregiver alert if the person
  doesn't act within a timeout. v1 only implements the first level (ambient highlight +
  static instruction card) — do not assume the others work yet.

## Step sequence (v1 draft, 8 steps)

| # | Action | Marker object | Optional |
|---|--------|---------------|----------|
| 1 | Fill the kettle with water | Kettle | No |
| 2 | Turn on the kettle | Kettle | No |
| 3 | Put a tea bag in the cup | Cup | No |
| 4 | Wait for the water to boil | Kettle | No |
| 5 | Pour the hot water into the cup | Cup | No |
| 6 | Add milk or sugar, if you'd like | Cup | **Yes** |
| 7 | Take the tea bag out | Cup | No |
| 8 | Enjoy your tea | Cup | No (completion) |

Object markers are **generic placeholder primitives** (colored translucent shapes + a text
label), not real 3D scans of a kettle/cup — this repo has no 3D asset pipeline yet. They are
positioned at fixed offsets relative to a detected tabletop plane. A real deployment would
need the caregiver/patient to either (a) drag-reposition markers over their real objects once
per space, or (b) use object recognition — neither is implemented in v1; see
`ImmersiveTaskView.swift` for the `// TODO` marking where repositioning would go.

## Known gaps (intentional, for a first prototype)

- No timeout/escalation logic yet (see above).
- No voice/audio playback yet — `spokenCue` strings exist in the model but nothing calls
  AVSpeechSynthesizer or similar yet.
- No persistence/progress tracking across sessions.
- No caregiver-facing companion view.
- Markers assume *a* horizontal table surface exists; there's no fallback UX yet if plane
  detection fails or no table is found.

These are reasonable next slices, not oversights — flagging them explicitly so the next
change knows where the seams are.
