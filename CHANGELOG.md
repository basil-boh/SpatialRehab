# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## [Unreleased]

### Removed

- **mac2visionOS / Mac Link** stack for the hackathon: SPM dependency, multiplatform macOS target, Bonjour/local-network Info.plist keys, sandbox network entitlements, and bubble host/controller/smoke/stability UI files. Local dev is **visionOS Simulator only**.

### Fixed

- (2026-08-07) `ContentView.startImmersiveSpace()` silently did nothing if
  `openImmersiveSpace` returned `.userCancelled` or `.error` — the screen looked identical
  to a tap that hadn't registered at all, with no way to tell them apart. Now shows a
  message on-screen for the cancelled/error cases and disables the button while opening.

### Added

- (2026-08-08) Cognitive-stimulation game recommendation engine, closing the
  "no recommendation engine" gap noted in `Docs/BaselineAssessment_Design.md`. Ranking
  logic only — teammates still need to wire this into an actual session-selection UI.
  - `SpatialRehab/Models/CognitiveDomain.swift` — `CognitiveDomain` (`.memory`,
    `.numeracy`, `.executiveFunction`) and `DomainScore` (a dated `0...1` reading).
  - `SpatialRehab/Models/StimulationGame.swift` — `StimulationGame` metadata and
    `StimulationGameCatalog`, mapping each domain to games from the product-vision doc's
    ability→exercise table.
  - `SpatialRehab/Models/GameRecommendationEngine.swift` — ranks domains by
    `priority = 1 - score` (weakest first); a plain weighted comparison, not a trained
    model, since one patient never has enough sessions to fit anything meaningful. Also
    adds `BaselineResultsStore.currentDomainScores()`, bridging the three scored trials
    (word memory, arithmetic, pattern matching) into the engine's input shape. Clock
    drawing stays excluded — no domain case exists for it while it's unscored, so it's
    never treated as a false "weakest" domain by default.
- (2026-08-08) Word-memory list tuned to **4 target words + 6 distractors** (10 in the
  recall grid) in `BaselineAssessmentContent.WordMemory` — briefly tried 4+4 first, then
  restored distractors to 6 per follow-up feedback while keeping the shorter 4-word study
  list. `studyDurationSeconds` (10s) unchanged throughout.
- (2026-08-08) `BaselineResultsDebugView` now renders each game's data as a colored circular
  `Gauge` (percentage score, one fixed identity hue per game — blue/purple/teal) plus a Swift
  Charts horizontal `BarMark` breakdown, instead of plain text rows:
  - Word Memory: Correct/Missed/Extra-taps counts (green/gray/orange).
  - Pattern Matching: Ideal moves vs Actual moves.
  - Arithmetic: per-problem checkmark/circle row (green = correct) alongside the gauge.
  - Clock Drawing unchanged — no chart, since it's deliberately unscored; shows a neutral
    "not scored" icon instead of fabricating a graph for a number that doesn't exist.
  Colors are status-based (green/gray/orange always mean correct/missed/flagged, never
  reused for anything else) — this is a dev-only screen, so the palette wasn't run through
  a formal colorblind-safety validator; worth doing if this ever becomes caregiver-facing.
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
