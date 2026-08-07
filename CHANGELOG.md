# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## [Unreleased]

### Fixed

- (2026-08-07) `ContentView.startImmersiveSpace()` silently did nothing if
  `openImmersiveSpace` returned `.userCancelled` or `.error` — the screen looked identical
  to a tap that hadn't registered at all, with no way to tell them apart. Now shows a
  message on-screen for the cancelled/error cases and disables the button while opening.

### Added

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
  - Gaze+pinch selection on all buttons (`Start Guided Task`, `Done`, `Back`, `Skip`) needed
    no code — it's visionOS's native input model for any SwiftUI control.
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
- Installed XcodeGen via Homebrew for this change; regenerated `SpatialRehab.xcodeproj` from
  `project.yml` so the new source files are registered.
- Initial visionOS app scaffold (`SpatialRehab` target, SwiftUI `@main` + placeholder `ContentView`).
- Xcode project generated via XcodeGen (`project.yml` → `SpatialRehab.xcodeproj`) with shared `SpatialRehab` scheme.
- visionOS platform config: deployment target **2.0**, bundle ID `com.spatialrehab.SpatialRehab`, automatic signing (team left empty for each developer).
- Asset catalog stubs (`AppIcon`, `AccentColor`).
- `Xcode_README.md` — how to open, sign, and run on visionOS Simulator for teammates new to Xcode.
- `AGENTS.md` — agent rule to always record edits in this changelog.
- Root `.gitignore` for Xcode / macOS noise.
