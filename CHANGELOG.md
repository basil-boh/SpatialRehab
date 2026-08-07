# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## [Unreleased]

### Added

- Simple welcome screen in `ContentView.swift`: app icon, title, short description of the app's purpose (helping dementia patients remember home, medication, and daily routines), and a "Get Started" button, styled for a comfortable visionOS window (large text, generous spacing).
- Default window size (900x600) set in `SpatialRehabApp.swift` for the welcome screen.

### Added (previous)

- Initial visionOS app scaffold (`SpatialRehab` target, SwiftUI `@main` + placeholder `ContentView`).
- Xcode project generated via XcodeGen (`project.yml` → `SpatialRehab.xcodeproj`) with shared `SpatialRehab` scheme.
- visionOS platform config: deployment target **2.0**, bundle ID `com.spatialrehab.SpatialRehab`, automatic signing (team left empty for each developer).
- Asset catalog stubs (`AppIcon`, `AccentColor`).
- `Xcode_README.md` — how to open, sign, and run on visionOS Simulator for teammates new to Xcode.
- `AGENTS.md` — agent rule to always record edits in this changelog.
- Root `.gitignore` for Xcode / macOS noise.
