# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## 2026-08-08

### Added

- **Wayfinding exercise — "Walk to the Bakery"** (second activity in the shared `ActivitySpace`):
  - `WayfindingExercise.swift` — `@Observable` model: traffic-light cycle (5 s red/green), waypoint progression, invisible metrics (taps-on-red inhibition errors, start/finish timestamps).
  - `WayfindingSpaceView.swift` — code-built street scene (sidewalks, road, zebra crossing, bakery storefront, primitive traffic light with named `redLamp`/`greenLamp` entities so the generated USDZ can drop in later). Locomotion = tap glowing waypoint → fade-out, world shifts, fade-in (no continuous motion, dementia-safe). Crossing waypoint gated on green light.
  - `AppModel.ActivityKind` + activity routing in the `ImmersiveSpace`; welcome screen now offers "Touch the Dots" and "Walk to the Bakery".
  - MapKit note for later: SwiftUI `Map` (incl. `.realistic` elevation) and `LookAroundPreview` are visionOS-available but flat-in-window only — no volumetric map, no RealityKit registration; planning-map window is a future add-on.
- First on-device deploy: signed with personal team `82785P97XY`, installed and launched on Aditya's Apple Vision Pro via `devicectl`.
- **"Find Your Way Home" exercise** (third activity, window-based, real Apple Maps data):
  - `FindHomeExercise.swift` — `MKDirections` walking route (demo: Tiong Bahru Market → Eng Hoon St), junctions derived from route *geometry* (heading change at step boundaries, not localized instruction strings), Look Around scene fetch per junction, invisible wrong-turn metric.
  - `FindHomeView.swift` — Look Around card (real street-level imagery) + 3D map card (route polyline, Home/Market markers, walking-figure annotation), left/straight/right arrow buttons, camera glides along the route on correct choices; gentle no-fail retry copy on wrong ones.
  - Runs in the main window (no immersive space); `ActivityKind.findHome` wired through AppModel/ContentView; welcome screen now offers three activities.
  - Verified: SwiftUI `Map`, `.realistic` elevation, and `LookAroundPreview` are all visionOS-available; Apple's 3D map mesh is not extractable into RealityKit (immersive map ruled out).
- **Immersive "you are there" street view for Find Your Way Home** (visionOS 26+, device runs 27):
  - `FindHomeExercise` now snapshots each junction's Look Around scene via `MKLookAroundSnapshotter` (1600×1200 JPEG to temp file).
  - `FindHomeImmersiveView.swift` — RealityKit `ImagePresentationComponent` turns the snapshot into a generated-depth **spatial scene** (`.spatial3DImmersive`, system progress UI during generation, flat-image fallback), displayed ~3× scale at 3.6 m in the shared ActivitySpace.
  - Find Home now opens the immersive space alongside the control window (map + arrows); `Done` dismisses the space; pre-26 devices fall back to window-only via availability guard.
- **Instant + fully immersive street** (feedback: "I should see the street immediately / like I'm there"):
  - `FindHomeExercise.prepare()` preloads at app launch: route, Look Around scenes, and snapshots for *all* junctions in route order; `begin()` restarts without refetching.
  - `SpatialStreetCache` pre-generates spatial scenes (deduped tasks) as snapshots land, warmed from `ContentView`; immersive view shows the flat street photo instantly, then swaps in the generated-depth version.
  - Find Home now uses **`.full` immersion** (passthrough replaced by the street); dots/bakery stay `.mixed` via a computed immersion-style binding. Clinical note: full immersion needs review for real patients (disorientation risk) — fine for the demo.
  - `startedAt` metric now begins at the first arrow choice, not preload.
- **True 360° "you are inside the street" panorama sphere** on arrival:
  - `PanoramaLoader` — loads any equirectangular JPEG, letterboxes partial-FOV captures (phone panoramas) to the required 2:1 with smeared edge fill; renders on an inverted 50 m sphere with unlit material — full look-anywhere immersion.
  - Demo asset `DemoStreetPanorama.jpg` — real 360° street junction (Wikimedia Commons, **CC BY 3.0, © Biswarup Ganguly**, Baghbazar Street, Kolkata; attribution required if shipped).
  - Reaching "home" in Find Your Way Home now drops the patient inside the panorama; junctions remain generated-depth spatial scenes (Apple exposes no 360° Look Around imagery — snapshot is the API ceiling).
  - Same renderer is ready for family-captured 360° photos of a patient's actual street (also powers the reminiscence-therapy feature).
- **Giant 3D Flyover city board in the immersive stage** ("put the user in Apple's 3D map"):
  - `FlyoverMapView` — Apple's photogrammetric 3D map (`.imagery(elevation: .realistic)`, Singapore is Flyover-covered) on a ~2.5 m tilted board (`Attachment`), camera swooping the route at pitch 70 between junctions, patient interaction disabled (`interactionModes: []`).
  - Street spatial scene switched from `.spatial3DImmersive` to framed `.spatial3D` above the board so both compose; arrival panorama sphere unchanged.
  - Note: Apple's 3D city mesh remains non-extractable — the board renders the live map view, which is the platform ceiling for "standing in the map."
- **Life-size 3D neighborhood mesh — patient stands IN the map** (chosen over Google Photorealistic 3D Tiles for hackathon feasibility):
  - `TiongBahruMap.json` — bundled OpenStreetMap extract (Overpass, ODbL): 135 building footprints (114 with storey counts), 381 road segments around the route.
  - `NeighborhoodWorld.swift` — runtime mesh generation: ear-clipped roof triangulation + double-sided extruded walls (heights from `building:levels`), road ribbons by highway class, ground plane, glowing orange home beacon (90 m), per-step route ribbons revealed only after being walked (no answer spoilers).
  - `NeighborhoodController` moves the world so the patient stands at each junction **facing their incoming direction of travel** (left/right choices are now egocentric — stronger clinical validity); fade-teleport between junctions; arrival places them at their front door.
  - `Junction` gained `incomingHeading`; immersive stage replaces the Flyover board + framed street scene (structs kept in code, unused); 360° panorama sphere reserved for reminiscence.
- **"Remember the Way" exercise** (fifth activity, window-based, pure Apple Maps — no street imagery):
  - `RouteMemoryExercise.swift` — study phase (interactive 3D Flyover map, route shown, 30 s countdown with skip), draw phase (map locked, drag trace via `MapReader`/`proxy.convert`, 6 m point decimation), scoring = mean distance from drawn points to the real route polyline in ENU meters, banded gentle feedback; wrong-turn-free, no-fail copy.
  - `RouteMemoryView.swift` — camera glides pitched-3D (study) → top-down (draw); scored state overlays real route vs the patient's orange trace; Start over / I'm done / Play again controls.
  - Wired as `ActivityKind.routeMemory` (no immersive space); welcome menu now five activities.
  - **Reworked to a holographic table** (feedback: "table typa map, Tony Stark vibes"): `RouteMemoryTableView` replaces the window version — the interactive Flyover map lies flat on a ~1.25 m attachment plane at table height (rotated −90° about X) in mixed-immersion passthrough, glass control panel floats behind it; drawing happens directly on the table surface. Window shows guidance text only; activity now opens the shared ActivitySpace.
  - Table map style switched from satellite imagery to `.standard(elevation: .realistic, pointsOfInterest: .excludingAll)` — clean cartographic look with 3D buildings, POI clutter removed (user feedback).
  - **True 3D buildings rising out of the table** (feedback: "buildings not extrapolating into my real world"): OSM building meshes mounted as a miniature city on the map surface — fixed north-up top-down camera, registration via `MapProxy.convert` (scale from a 100 m east baseline, offset from the route-start view point, ~1360 pt/m attachment constant), visible-region building culling, 1.7× height exaggeration; camera glides removed (fixed camera keeps mesh and map aligned).
  - **Animated draw-on route** in the study phase: screen-space `RoutePathShape` (valid under the fixed camera) traced with `.trim` over ~4.5 s, smoothstep easing, glowing white head dot interpolated along cumulative path length, 3.5 s hold, then repeats for the whole study window (repetition aids encoding); replaces the static study polyline, scored-phase comparison polyline unchanged.
  - **Grab, place, resize, and step inside**: metal grab-handle bar under the table front edge (`DragGesture.targetedToEntity` moves the whole rig anywhere, incl. the floor); Bigger/Smaller buttons scale 0.3×–3× pivoting on the table center; **"Step inside"** tweens the rig to 1:1 over 1.6 s — the miniature becomes the life-size neighborhood around the patient (map plane + handle hidden; miniature reparented to the rig via `setParent(preservingWorldTransform:)` to survive the table hiding); "Back to table" restores. Control panel stays fixed and readable throughout.
  - **Hands-first scaling + real-world-fitting life size**: two-hand `MagnifyGesture` on the miniature's collision bounds (buttons remain as accessible fallback; building input target auto-removed during drawing so it can't intercept gaze meant for the map); step-inside reworked — route start lands ~1.5 m ahead, 1.7× height exaggeration animates back to true 1:1 during the zoom, and life-size mode reveals roads + the glowing cyan route ribbon standing on the patient's real floor (no ground plane or sky — passthrough room is the world).
  - **Step inside is now fully immersive**: `AppModel.routeMemoryInside` drives the shared space's immersion-style binding (`.mixed` at the table → `.full` inside, live transition while the zoom tween runs); life-size extras upgraded to the complete dusk world — ground, sidewalks, roads, route ribbon, trees, gradient sky dome, sunset light, home beacon; "Back to table" and space dismissal both restore passthrough.
- **Seated comfort navigation in the step-inside world** (feedback: no jarring motion, patient seated at all times):
  - Pinch-and-hold anywhere on the city = glide forward along the route at a constant 1.1 m/s (0.15 s ramp — constant velocity avoids vestibular acceleration triggers); release = stop. Path-on-rails along the walking route: no steering or wayfinding burden.
  - Route simplified to meaningful vertices (≥10° turns); micro-bends snap invisibly; corners >25° take a **blink turn** (120 ms fade → reorient → fade in) — no smooth world rotation ever.
  - Step-inside now lands the patient at the route start facing along the ribbon (shared `walkTransform` math); study countdown pauses while inside (`pauseStudy`/`resumeStudy`), resumes at the table; walk loop cancelled on exit/dismiss.
- **Home pin marker** (replaces the abstract orange beacon in both immersive worlds): classic red map pin (inverted cone + sphere + white dot) floating above the rooftops at the destination, with a faint red light column for find-it-from-anywhere visibility.

### Fixed

- Walk glide speed raised 1.1 → 2.2 m/s (user: too slow); still constant-velocity for comfort.
- **Gesture interception breaking normal interaction** (user report: "pinching not working kinda"): the walk gesture was `targetedToAnyEntity` with zero minimum distance, competing with every pinch including control-panel buttons, and at life size the patient sat *inside* the city's collision box which swallowed gaze. Now: walk gesture targets a dedicated ground `walkSurface` (lives in the life-size extras, so it cannot exist at table scale), zoom targets the city entity only, and the city's input target is removed both in inside mode and during drawing (`updateCityInput`). Stable `city`/`walkSurface` entities replace the optional miniature reference so gestures bind at view build time.
- **Two-hand zoom too sensitive**: magnification ratio damped with `pow(m, 0.55)` — a large hand spread now produces a gentle, controllable size change.
- **Free table gestures removed entirely** (dementia-first redesign; user report: grab/zoom still raced Draw and Step-inside buttons and grabbing felt jarring): the grab handle and two-hand magnify are gone — the patient can never accidentally move or resize the world. Replaced by a caregiver **"Adjust table"** panel section (collapsed by default): Smaller/Bigger steps (1.3×, animated about the table center), "Table height" / "On the floor" placement presets, and Reset. The only remaining spatial gesture is pinch-the-street-to-walk in life-size mode.
- **Realism pass on the neighborhood mesh** (`NeighborhoodWorld` largely rewritten; both Find Home and step-inside get it):
  - **Buildings**: lit shophouse ground floors (warm glass, doors, striped awnings, five-foot-way columns) shared across all buildings; upper storeys bucketed into 4 Tiong Bahru pastel facade styles (cream/white/yellow/green, mullioned windows, sills, optional balcony rails, varied lit bays) — per-quad UVs, one draw call per bucket via new `MeshBatch` helper.
  - **Streets**: tiled asphalt texture on roads, dashed white center lane markings (2.2 m dashes / 7.5 m period, drivable roads only), paver-textured sidewalks.
  - **Environment**: ~140 merged street lamps (dark poles + arms, warm unlit heads, alternating road sides, building-collision rejection), varied 2-tuft trees in 3 greens, blotchy grass ground texture (24× tiling), sky gains horizon sun glow + 90 early stars, cool blue fill light added opposite the sunset key light.
- **Dusk-city polish for the OSM neighborhood** (user chose stylized-polish over photoreal paths):
  - Procedural CoreGraphics facade texture (four window bays per 12 m, one storey per repeat, one warm-lit window) on UV-mapped extruded walls (`PhysicallyBasedMaterial`); separate flat-gray roof mesh.
  - Gradient dusk sky dome (indigo → peach horizon, inverted 550 m sphere), warm directional "sunset" light, greenish ground, sidewalk ribbons beside every road, 60 seeded street trees with building/road rejection sampling.

- **Touch-the-dots warm-up prototype** (first playable slice of the daily loop):
  - `AppModel.swift` — app-wide `@Observable` session model (`welcome → openingActivity → inActivity → finished`) shared across window and immersive space.
  - `TouchTheDotsGame.swift` — game state: 10 dots one at a time, randomized reachable positions (min 0.35 m apart), invisible per-dot reaction-time metrics for the future baseline profile.
  - `TouchTheDotsSpaceView.swift` — mixed-immersion `RealityView`: glowing tappable spheres (generous collision target, gaze hover effect), floating "Touch the glowing circle" prompt attachment, pop animation, auto-dismiss back to the window when done.
  - `ImmersiveSpace(id: "ActivitySpace")` with `.mixed` immersion added to `SpatialRehabApp.swift` — the single shared activity space all future games plug into.

### Changed

- `ContentView.swift` reworked from static welcome screen to patient-mode flow: warm-up intro → in-activity guidance → "Well done!" wind-down, one action on screen at a time, capsule buttons.
- `SpatialRehab.xcodeproj` — registered the three new Swift sources (hand-edited pbxproj; xcodegen not run to avoid clobbering uncommitted asset additions).

## [Unreleased]

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
