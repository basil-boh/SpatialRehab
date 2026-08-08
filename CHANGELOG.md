# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## [Unreleased]

### Fixed

- (2026-08-09) Hub tile dot grids barely appeared to move: the difficulty schedule only
  guaranteed one step forward every 3 completed rounds, which on a 30-dot grid read as "the
  dots aren't moving" during normal testing (2 of every 3 rounds produced no visible change).
  `PracticeProgressStore`'s `levelsPerScheduledDifficultyIncrease` changed from 3 to 1 — every
  completed round now guarantees at least one step forward by default; performance can still
  pull ahead or hold back on top of that.
- (2026-08-09) Draw & Trace's hub tile had no dot grid at all (the only one of the four with
  no visual progress indicator), since it has no difficulty scale to show. Added one anyway,
  showing something else real and already bounded at 30: `GameProgress.visitedDrawingSubjectIDs`
  — a permanent "collected" mark per subject, filling in as each of the 30 subjects gets drawn
  for the first time. `PracticeProgressStore.recordCompletion` gained an optional
  `visitedDrawingSubjectID` parameter; `PracticeGameContainerView` passes the current
  drawing subject's id through it.

### Added

- (2026-08-09) Draw & Trace expanded from 11 subjects to 30 (matching the other three games'
  1–30 scale), plus a real difficulty axis it previously had none of.
  - `DrawingSubjects.all` grew from clock + 10 objects to clock + 29 objects (phone, letter,
    bag, fork & knife, book, bell, lightbulb, scissors, glasses, shirt, suitcase, bed, shoe,
    comb, bathtub, fan, backpack, camera, bicycle, added to the original dog/cat/house/
    tree/sun/fish/car/cup/umbrella/key) — all verified against the installed SDK before use.
  - New difficulty axis: **outline fading** (`DrawingSubjects.outlineOpacity(forLevel:)`),
    based on the "vanishing cues" technique used in dementia memory care — the traceable
    outline starts at its original fixed opacity (0.25) on the first pass through all 29
    objects, fades a little on each subsequent full pass, floored at 0.06 so it's never
    actually invisible. Chosen over trying to make the *shapes* harder, which isn't a
    well-defined axis for a silhouette outline.
  - `ClockDrawingView` takes a new `outlineOpacity` parameter (default 0.25, so the baseline
    call site's appearance is unchanged) and stays unaware of "levels"/fading logic itself —
    it just renders whatever opacity it's given.
  - `Docs/DailyPractice_Design.md` updated with the rationale.
- (2026-08-09) Difficulty widened from 5 levels to 30, and the difficulty rule now guarantees
  gradual progress instead of only moving on a strong performance signal.
  - `PracticeDifficulty.levelRange` is now `1...30` (was `1...5`); word memory, pattern
    matching, and arithmetic content-scaling formulas rewritten for the wider range (word
    bank kept at 22 words, pattern-matching symbol pool expanded from 8 to 12 verified SF
    Symbols to support up to 12 pairs).
  - `PracticeProgressStore.recordCompletion` now combines a **gradual schedule** (difficulty
    has a floor that rises with `visibleLevel`, so it never sits flat regardless of score)
    with the existing **performance nudge** (great performance pulls ahead of schedule,
    struggling eases back) — fixes a real gap where scores in the "fine, not great, not
    struggling" middle band left difficulty completely unchanged, which read as "the levels
    aren't actually getting harder."
  - `GameProgress.difficultyTier` renamed to `difficultyLevel` throughout.
- (2026-08-09) `DailyPracticeHubView`'s per-tile dots now show **difficulty-level progress**
  (a compact 10-column grid, filled up to the current level out of 30) instead of the old
  7-day practice streak — the streak moved to its own screen, below.
- (2026-08-09) New **Practice Calendar** screen (`PracticeCalendarView.swift`), reached via a
  corner calendar button on `DailyPracticeHubView`:
  - A month-grid calendar (green dot on any day something was practiced — the "GitHub
    contributions" idea, reshaped into a familiar month layout rather than a week-column
    heatmap) built from the union of all four games' practiced-day sets.
  - A Duolingo-style current-streak counter (flame + "N days in a row"); an in-progress
    streak still counts through today even before today's session happens, and a missed day
    quietly resets it with no "you broke your streak" messaging anywhere.
  - Permanent streak badges (7-day, 30-day) — tracked separately from the live streak
    (`PracticeProgressStore.longestCombinedStreak()`, a persisted high-water mark) so a badge
    stays earned even after a later missed day resets the current streak back to 0.
  - A per-game breakdown list (each game's own current streak), satisfying "tracking for each
    style of task" now that the hub tiles no longer show it directly.
  - `Docs/DailyPractice_Design.md` updated throughout for all of the above.
- (2026-08-08) Draw & Trace: the drawing game now cycles through a different subject each
  level instead of only ever drawing the clock.
  - `SpatialRehab/Models/DrawingSubject.swift` — level 1 stays the clock (free-recall, no
    reference shown, unchanged Clock Drawing Test format); every level after cycles through
    common animals/objects (dog, cat, house, tree, sun, fish, car, cup, umbrella, key), each
    shown as a faint traceable SF Symbol silhouette. Tracing rather than pure recall is a
    deliberate, gentler mechanic for this population, aimed at jogging recognition/naming of
    everyday items.
  - SF Symbol names were verified against the installed visionOS 27 SDK (compiled and ran a
    small `UIImage(systemName:) != nil` check inside the Simulator) before use, not assumed —
    `flower.fill`/`butterfly.fill` don't exist in this SDK and were dropped from the list.
  - `ClockDrawingView` takes an optional `subject` parameter (default = the clock, so the
    baseline call site is unchanged) and renders the outline behind the canvas, baked into
    the saved PNG.
  - `ClockDrawingResult` gained `subjectID` (defaults to `"clock"`) so a later reviewer knows
    what was drawn, not just a bare sketch. Saved-file prefix now uses the subject id (e.g.
    `dog-drawing-…png`) instead of a fixed `clock-drawing-` prefix.
  - `PracticeGameKind.clockDrawing`'s hub title changed from "Draw a Clock" to "Draw & Trace"
    to reflect the expanded scope.
  - `Docs/DailyPractice_Design.md` updated with the mechanic rationale and known-gap
    reasoning for why tracing (not recall) was chosen for the new subjects.
- (2026-08-08) **Daily Practice** hub: a new, repeatable version of the four baseline-battery
  mini-games (word memory, pattern matching, arithmetic, clock drawing), separate from the
  one-time baseline battery — see `Docs/DailyPractice_Design.md` for the full rationale.
  - Levels and difficulty are deliberately split: a **visible level** per game that only ever
    climbs (never computed from performance, so it can never read as a grade), and a
    **hidden, adaptive difficulty tier** (1–5) that drives actual content — word count, pair
    count, arithmetic complexity — using each result type's already-computed `score`. The
    tier number itself is never shown to the patient, only its effects. Reconciles "feels
    like a real game with levels" with the existing hard rule that scores/right-wrong are
    never surfaced to the patient.
  - `PracticeGameKind.swift` — the four game identifiers + display metadata (title, icon,
    tint, whether adaptive).
  - `PracticeDifficulty.swift` — tier-scaled content generators. Word memory and arithmetic
    generate fresh content each round (sampled from a larger word bank / generated within a
    tier's number range) rather than reusing the baseline's fixed lists, so a daily-repeated
    game doesn't get memorized instead of practiced.
  - `PracticeProgressStore.swift` — local `UserDefaults` persistence (matching
    `BaselineResultsStore`'s pattern) for each game's level, difficulty tier, and the set of
    days it's been practiced — tracked **per game type**, not one combined streak, per the
    product ask.
  - `Views/DailyPracticeHubView.swift` — the hub: a tile per game showing its level and a
    7-day practice-dot row (filled/empty only — never red, never a percentage, no
    "you missed a day" messaging), plus a simple "X of 4 today" completion line.
  - `Views/PracticeGameContainerView.swift` — generates one round's tier-scaled content,
    hosts the relevant game view, records progress on completion, and shows a brief
    purely-positive "Nice work! Level N" screen before returning to the hub.
  - `WordMemoryGameView`, `PatternMatchingGameView`, `ArithmeticGameView` now take optional
    content parameters (word lists / symbols / problems) defaulting to the exact baseline
    content, so every existing baseline call site is unchanged — the Daily Practice hub
    passes tier-scaled content instead, reusing the same views rather than duplicating them.
  - Added a small in-round progress bar directly to `PatternMatchingGameView` (pairs found /
    total) and `ArithmeticGameView` (problem N / total) — neutral positional information, not
    a correctness signal, so it's a free improvement for the baseline flow too.
  - `ContentView` now leads with a primary "Daily Practice" button; the existing "View
    Baseline Data (Dev)" button stays, de-emphasized.
  - `ClockDrawingView`'s saved-file prefix renamed from `baseline-clock-` to
    `clock-drawing-`, since it's now also used repeatedly from Daily Practice, not just the
    one-time baseline.
  - Regenerated `SpatialRehab.xcodeproj` via `xcodegen generate` to register the new files.

### Removed

- **mac2visionOS / Mac Link** stack for the hackathon: SPM dependency, multiplatform macOS target, Bonjour/local-network Info.plist keys, sandbox network entitlements, and bubble host/controller/smoke/stability UI files. Local dev is **visionOS Simulator only**.

### Fixed

- (2026-08-07) `ContentView.startImmersiveSpace()` silently did nothing if
  `openImmersiveSpace` returned `.userCancelled` or `.error` — the screen looked identical
  to a tap that hadn't registered at all, with no way to tell them apart. Now shows a
  message on-screen for the cancelled/error cases and disables the button while opening.

### Added

- (2026-08-08) `ContentView.swift`'s "Get Started" flow — which previously opened the AR
  "Making Tea" immersive task — is disabled while baseline-metrics is the active focus.
  Replaced with a dev-only "View Baseline Data (Dev)" button that presents the new
  `SpatialRehab/Views/BaselineResultsDebugView.swift`: a raw data dump (target/tapped
  words, pattern-matching pairs/moves, arithmetic per-problem answers, clock-drawing
  capture timestamp + saved sketch image) read directly from `BaselineResultsStore`, for
  verifying scoring/capture without leaving the app. The patient-facing baseline summary
  screen still shows **no score** — this is a separate, explicitly dev-only surface.
  `SpatialRehabApp` still declares the `ImmersiveSpace` scene and owns `teaSession` so the
  AR task isn't deleted, just unreachable from this entry point for now.
- (2026-08-08) Word-memory game refinements: a visible study countdown (number + progress
  bar) instead of a silent timer, selected words now highlight in **green only** (removed
  the per-word pastel color palette added earlier the same day), and word taps use a new
  softer `SoundEffects.playSoftTap()` (system sound 1103) instead of the shared `playTap()`
  used by the other games.
- (2026-08-08) Baseline assessment now runs on **every launch**, temporarily, for easier
  testing while the battery is under active development: `SpatialRehabApp.hasCompletedBaseline`
  changed from `@AppStorage` (persisted across launches) to plain `@State` (resets every
  launch). Swap back to `@AppStorage("baseline.hasCompletedBaseline")` once the battery is
  stable and this should genuinely be first-launch-only again — see the comment on that
  property and the matching note in `Docs/BaselineAssessment_Design.md`.
- (2026-08-08) First-launch Baseline Metric assessment: a short cognitive battery (clock
  drawing + word-memory recognition) shown once before the existing welcome screen, so
  future sessions can eventually be measured against a starting point.
  - `Docs/BaselineAssessment_Design.md` — design rationale (recognition-vs-recall,
    no-live-feedback, why the clock test is intentionally unscored), plus known gaps.
  - `SpatialRehab/Models/WordMemoryTrial.swift`, `ClockDrawingResult.swift`,
    `BaselineAssessmentContent.swift` — result models and placeholder game content (not
    clinically reviewed).
  - `SpatialRehab/Models/BaselineAssessmentSession.swift` — `@Observable` linear phase
    machine (intro → wordMemory → clockDrawing → summary); new code, so uses `@Observable`
    rather than the `ObservableObject` pattern `TaskSession` predates.
  - `SpatialRehab/Models/BaselineResultsStore.swift` — small `UserDefaults`-backed
    persistence for baseline results, kept simple since the real analytics store
    (`feature/analytics`) isn't merged into `main` yet.
  - `SpatialRehab/Views/WordMemoryGameView.swift` — study a short word list, then tap
    remembered words from a shuffled target+distractor grid; no color-coded right/wrong
    feedback.
  - `SpatialRehab/Views/ClockDrawingView.swift` — free-draw `Canvas` + `DragGesture`
    capture, rasterized to PNG via `ImageRenderer` and saved to the Documents directory;
    unconditional "Clear" (no penalty); `score` stays `nil` for later caregiver review.
  - `SpatialRehab/Views/BaselineAssessmentView.swift` — wires the flow together; never
    surfaces scores to the patient; "Exit for now" available on every phase.
  - `SpatialRehabApp.swift` — gates the `WindowGroup` body on a persisted
    `baseline.hasCompletedBaseline` `@AppStorage` flag instead of adding a second window
    scene, to avoid two windows opening at once on first launch.
  - Regenerated `SpatialRehab.xcodeproj` via `xcodegen generate` to register the new files.
- (2026-08-08) Expanded the Baseline Metric battery from 2 to 4 games, and added light
  audio/visual feedback to the tap-based games.
  - `SpatialRehab/Models/PatternMatchingResult.swift`, `ArithmeticResult.swift` — new result
    models (pattern-matching scored by move efficiency, arithmetic by correct/total, both
    computed silently and never shown to the patient).
  - `SpatialRehab/Views/PatternMatchingGameView.swift` — classic memory-flip pairs game (6
    symbol pairs); mismatches flip back calmly after a beat, no penalty/negative feedback.
  - `SpatialRehab/Views/ArithmeticGameView.swift` — basic single-digit addition, tap the
    correct sum from 4 choices, no typing.
  - `SpatialRehab/Models/SoundEffects.swift` — shared soft tap/success sound helper
    (`AudioServicesPlaySystemSound`); deliberately gentle, not celebratory, for this
    audience. Known limitation: relies on undocumented system sound IDs — a production pass
    should bundle custom short audio assets instead.
  - `WordMemoryGameView.swift` — added a per-word pastel color tint (derived from the word's
    own text, blind to target/distractor status) and a scale-bounce animation + tap sound on
    selection; still no right/wrong signal anywhere.
  - `BaselineAssessmentSession.swift`/`BaselineAssessmentView.swift`/
    `BaselineResultsStore.swift`/`BaselineAssessmentContent.swift` updated for the new
    `patternMatching`/`arithmetic` phases in the battery order (word memory → pattern
    matching → arithmetic → clock drawing → summary).
  - `Docs/BaselineAssessment_Design.md` updated battery table and rationale.
- (2026-08-08) Fixed `ClockDrawingView` content (prompt + 480pt canvas + buttons) overflowing
  and clipping inside the shared 900×600 default window. Reduced the canvas to 400pt and
  tightened spacing/padding; also bumped `SpatialRehabApp`'s shared `.defaultSize` to
  900×780 so there's comfortable margin for this and future baseline screens. Other screens
  (welcome, guidance card, baseline intro/summary) are centered content, so the extra height
  just adds margin, not a layout change.
- (2026-08-07) Confirmed AR (not VR) and added real hand-tracking-based step confirmation.
  - `SpatialRehabApp.swift` now pins the `ImmersiveSpace` to `.immersionStyle(... in: .mixed)`
    explicitly, so passthrough + composited virtual content is guaranteed, not just the
    (already-default) assumption.
  - `SpatialRehab/Models/HandProximityTracker.swift` — new. Uses ARKit's
    `HandTrackingProvider` to read live index-fingertip joint positions and reports distance
    to a world-space target. `ImmersiveTaskView` uses it to auto-advance a step when a hand
    gets within 12cm of the active marker; the manual "Done" button in `GuidanceCardView`
    remains a required fallback, not replaced.
  - `NSHandsTrackingUsageDescription` added (`Info.plist` and `project.yml`) alongside the
    existing `NSWorldSensingUsageDescription`. Verified against the installed visionOS 27
    SDK that no additional entitlement is needed for hand tracking (authorization-prompt
    gated only, like camera/location).
  - Gaze+pinch selection on all buttons (`Get Started`, `Done`, `Back`, `Skip`) needed no
    code — it's visionOS's native input model for any SwiftUI control.
  - Installed the visionOS 27.0 Simulator runtime (was missing) and verified this build end
    to end: `xcodebuild` → `simctl install` → `simctl launch` → screenshot, confirming the
    window renders correctly composited over the Simulator's furnished-room passthrough.
- (2026-08-07) First content prototype: guided "Making a Cup of Tea" task.
  - `Docs/TaskDesign_MakingTea.md` — draft task-analysis/cueing spec (errorless learning,
    minimal choices, single-step cues), including explicitly flagged known gaps.
  - `SpatialRehab/Models/TaskStep.swift`, `TeaTaskContent.swift`, `TaskSession.swift` —
    step content model and linear progression state machine.
  - `SpatialRehab/Views/GuidanceCardView.swift` — 2D step-instruction card (dot progress,
    Done/Back/Skip).
  - `SpatialRehab/Views/ImmersiveTaskView.swift` — immersive-space RealityView that anchors
    placeholder object markers (kettle/cup primitives) to a detected tabletop plane and
    shows only the current step's marker.
  - `SpatialRehabApp.swift` now declares an `ImmersiveSpace` alongside the main
    `WindowGroup`; `ContentView.swift` starts/ends it and hosts the guidance card.
  - `NSWorldSensingUsageDescription` added (`Info.plist` and `project.yml`) — required for
    tabletop plane detection.
- Simple welcome screen in `ContentView.swift`: app icon, title, short description of the
  app's purpose (helping dementia patients remember home, medication, and daily routines).
- Installed [visionOSAgents](https://github.com/tomkrikorian/visionOSAgents) skills under **`.skills/`** (22 skills: RealityKit, ARKit, spatial SwiftUI, architecture, USD, SharePlay, etc.).
- `.agents/skills` → symlink to `.skills` for agent-harness discovery (single copy of files).
- Installed **full [mattpocock/skills](https://github.com/mattpocock/skills) pack** under `.skills/` (engineering, productivity, misc, in-progress; snapshot `84fdeff`) alongside visionOS skills — not a second copy under `.agents/` (symlink only).
- `CLAUDE.md` — copy of `AGENTS.md` so Claude Code auto-loads the same repo rules.
- `AGENTS.md` — documents skills layout, full mattpocock process skill loop, visionOS platform map, and `CLAUDE.md` parity; every coding agent must load guidance from `.skills/` before writing visionOS / Swift code.
- `.skills/SOURCE.md` — dual-pack provenance, inventory, and refresh scripts (no `--delete` over visionOS or mattpocock packs).

### Changed

- Merged the welcome screen with the guided-task flow in `ContentView.swift`: the
  **Get Started** button (previously a no-op placeholder) now opens the guided task the
  same way the earlier **Start Guided Task** button did; `SpatialRehabApp.swift` keeps both
  the `.defaultSize(900, 600)` window sizing and the `ImmersiveSpace` declaration.
- `project.yml` / `SpatialRehab.xcodeproj` restored to **visionOS-only**; `Xcode_README.md` and `.skills/VISIONOS_AGENTS.md` updated for simulator-first hackathon flow.
- Default window size (900x600) set in `SpatialRehabApp.swift` for the welcome screen.
- Installed XcodeGen via Homebrew for this change; regenerated `SpatialRehab.xcodeproj` from
  `project.yml` so the new source files are registered.

- Initial visionOS app scaffold (`SpatialRehab` target, SwiftUI `@main` + placeholder `ContentView`).
- Xcode project generated via XcodeGen (`project.yml` → `SpatialRehab.xcodeproj`) with shared `SpatialRehab` scheme.
- visionOS platform config: deployment target **2.0**, bundle ID `com.spatialrehab.SpatialRehab`, automatic signing (team left empty for each developer).
- Asset catalog stubs (`AppIcon`, `AccentColor`).
- `Xcode_README.md` — how to open, sign, and run on visionOS Simulator for teammates new to Xcode.
- `AGENTS.md` — agent rule to always record edits in this changelog.
- Root `.gitignore` for Xcode / macOS noise.
- `AGENTS.md` — team roster (Aditya, Brian, JingTong, Nicole, Basil) with roles and deliverables.
- `.gitignore` — ignore `.omc/` (oh-my-claudecode local agent state; should not be committed).
