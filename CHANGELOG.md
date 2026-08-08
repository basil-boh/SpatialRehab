# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## [Unreleased]

### Added

- **Who am I? name card** (`szehao-id-card`): dementia-friendly identity ritual. Welcome **Who am I?** opens nest + circle-draw pad (Simulator drag loop or **Summon** button). Completing an approx circle presents a glowing NRIC-style card (Lim Chio Bu / 林招母, birthday, emoji portrait) in a second window. **Family** flips to a soft yellow tree (Ah Pek + three children; Sze Hao under Mei Ling). Pinch photo → greeting turn with bilingual relation caption; **Sze Hao** plays a 4s demo line then auto-closes. **Put away** flies the card back to the nest. Files under `SpatialRehab/WhoAmI/`; windows `who-am-i` + `name-card`. `Xcode_README.md` lists the welcome entry.
- **First-person VR walk (ImmersiveSpace)**: full immersion path toward Block 343 with **hand-tracking pinches** — left pinch = step / hold to keep walking, right pinch + hand L/R = turn (hold continues). Floating HUD, green destination door, **“You have arrived”** banner. Button fallback for Simulator. `HandPinchLocomotion` + `NSHandsTrackingUsageDescription`. Launch: **Walk in VR (first person)** → `yishun-vr-walk`.
- **Yishun MapKit guided walk** (`szehao-mapkit-yishun-walking`): fixed walking route from Northpoint City → Block 343 Yishun Ave 11 using `MKDirections` + SwiftUI `Map` polyline, virtual walker progress with start/pause/next, dementia-friendly crossing prompts, MapKit Look Around along the path, curated traffic-light POIs with slow state cycles, and a volumetric placeholder RealityKit traffic light (named `RedLight` / `YellowLight` / `GreenLight` for a future USDZ swap). Entry from welcome via **Yishun Walking Route**; shared `WalkSessionModel` syncs map markers and the volume preview.
- Files under `SpatialRehab/YishunWalk/` (route loader, session model, map, Look Around, guidance, Reality placeholder); `WindowGroup` ids `yishun-walk` and `traffic-light-preview` in `SpatialRehabApp.swift`.

- Hummingbird volumetric window: `hummingbird_anim.usdz` added to the app bundle, a new `HummingbirdVolumeView.swift` displays it via `Model3D` with `.manipulable()` so it can be grabbed, moved, and rotated by hand, and a second `WindowGroup(id: "hummingbird")` with `.windowStyle(.volumetric)` declares the scene in `SpatialRehabApp.swift`. The "Get Started" button in `ContentView.swift` now opens it via `openWindow(id:)`.

### Changed

- `project.yml` minimum deployment raised from visionOS **2.0** to **26.0** — required by the `.manipulable()` gesture API used for hand interaction with the hummingbird model. This narrows device/OS support versus the prior floor; revisit if older visionOS targets become a requirement.

### Removed

- **mac2visionOS / Mac Link** stack for the hackathon: SPM dependency, multiplatform macOS target, Bonjour/local-network Info.plist keys, sandbox network entitlements, and bubble host/controller/smoke/stability UI files. Local dev is **visionOS Simulator only**.

### Added

- Simple welcome screen in `ContentView.swift`: app icon, title, short description of the app's purpose (helping dementia patients remember home, medication, and daily routines), and a "Get Started" button, styled for a comfortable visionOS window (large text, generous spacing).

### Changed

- `project.yml` / `SpatialRehab.xcodeproj` restored to **visionOS-only**; `Xcode_README.md` and `.skills/VISIONOS_AGENTS.md` updated for simulator-first hackathon flow.
- Default window size (900x600) set in `SpatialRehabApp.swift` for the welcome screen.
- Installed [visionOSAgents](https://github.com/tomkrikorian/visionOSAgents) skills under **`.skills/`** (22 skills: RealityKit, ARKit, spatial SwiftUI, architecture, USD, SharePlay, etc.).
- `.agents/skills` → symlink to `.skills` for agent-harness discovery (single copy of files).
- Installed **full [mattpocock/skills](https://github.com/mattpocock/skills) pack** under `.skills/` (engineering, productivity, misc, in-progress; snapshot `84fdeff`) alongside visionOS skills — not a second copy under `.agents/` (symlink only).
- `CLAUDE.md` — copy of `AGENTS.md` so Claude Code auto-loads the same repo rules.
- `AGENTS.md` — documents skills layout, full mattpocock process skill loop, visionOS platform map, and `CLAUDE.md` parity; every coding agent must load guidance from `.skills/` before writing visionOS / Swift code.
- `.skills/SOURCE.md` — dual-pack provenance, inventory, and refresh scripts (no `--delete` over visionOS or mattpocock packs).
- Initial visionOS app scaffold (`SpatialRehab` target, SwiftUI `@main` + placeholder `ContentView`).
- Xcode project generated via XcodeGen (`project.yml` → `SpatialRehab.xcodeproj`) with shared `SpatialRehab` scheme.
- visionOS platform config: deployment target **2.0**, bundle ID `com.spatialrehab.SpatialRehab`, automatic signing (team left empty for each developer).
- Asset catalog stubs (`AppIcon`, `AccentColor`).
- `Xcode_README.md` — how to open, sign, and run on visionOS Simulator for teammates new to Xcode.
- `AGENTS.md` — agent rule to always record edits in this changelog.
- Root `.gitignore` for Xcode / macOS noise.
- `AGENTS.md` — team roster (Aditya, Brian, JingTong, Nicole, Basil) with roles and deliverables.
- `.gitignore` — ignore `.omc/` (oh-my-claudecode local agent state; should not be committed).
