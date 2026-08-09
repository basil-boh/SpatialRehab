# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## 2026-08-09

### Added

- **Persistent "Who am I?" button everywhere except the baseline assessment** (user request:
  a guide for dementia patients to remember who they are, reachable no matter where they are
  in the app). New `WhoAmI/WhoAmIButton.swift` — one reusable orange capsule button that
  presents the name card and opens the `name-card` window — hosted in two places so it is
  always on screen: a bottom **ornament** on the main window (rides the window itself, so it
  keeps the same spot across the home screen, Daily Practice, and the caregiver-dashboard
  sheet), and a fixed bottom row in `RouteMemoryTableView`'s control panel (the main window
  is dismissed while Remember the Way runs, so the panel is the only surface left). The
  ornament is attached only to the post-baseline branch in `SpatialRehabApp`, so the baseline
  battery never shows a mid-test escape. The inline "Who am I?" buttons on `ContentView`'s
  welcome/finished screens are removed in favor of the single consistent ornament; the
  `"name-card"` window id is centralized as `SceneID.nameCard`; `whoAmISession` is now also
  injected into the activity `ImmersiveSpace`'s environment. `RouteMemoryView`'s table-adjust
  controls moved unchanged into a private `adjustRow` helper during the panel edit.
  `SpatialRehab.xcodeproj` regenerated via `xcodegen` to pick up the new file.

- **"Who am I?" card visual redesign** (user report: "it looks very plain… I want the UI/UX
  to look great and professional"). Face side is now a proper identity-card layout: real
  portrait photo (new `whoami-owner` imageset, downscaled from a provided photo) in a
  rounded-rect frame with gradient ring and breathing glow, "MEMORY CARD · 记忆卡" header,
  bilingual "THIS IS YOU" eyebrow, rounded-display name typography, birthday + age chips,
  hairline gradient rules, and layered card chrome (glass → warm radial washes → faint
  watermark → hairline gradient border). Choreographed entrances: staggered fade-up rows
  (~60 ms apart), one-shot light sheen sweep on present, all gated behind Reduce Motion.
  Family tree side (`FamilyTreeView`) moved from the flat cream slab to warm glass, tiles
  are now material cards with correct hover shapes (`.borderless` + matching
  `buttonBorderShape`, per the buttons skill), and avatars support photos
  (`FamilyMember.photoName`). Greeting turn refreshed to match (serif quote line, relation
  capsule, softer frames). `FamilyMember` gained `photoName` and an `age` helper.

- **Family tree rebuilt in real genealogy layout** (user report: "i dont like how the family
  tree looks"). Connector lines are no longer eyeballed with width fractions — every tile
  registers its bounds via `anchorPreference` and a `ConnectorsShape` draws stem → rail →
  per-child drops from the resolved rects, so the lines stay glued to the layout at any
  size. A glass heart node sits between the spouses (classic marriage-node genealogy
  notation) and the stem grows out of it; the whole path draws itself in sequence with one
  `.trim`, after the couple tiles have landed and before the children rise in. Tiles are
  generation-sized (couple 92pt avatars > children 78 > grandchild 62), the self tile gets
  a warm tint + photo, Sze Hao's avatar carries a small play badge since he has a greeting
  video, the "Pinch for grandchild" hint became a proper `Grandchild · 孙子` capsule, and a
  faint tree watermark sits in the panel corner. All entrances stagger generation by
  generation and skip under Reduce Motion.

- **Every family member now has a connector line touching them, and the card watermark is
  black** (user request). `ConnectorsShape` gained marriage stubs — husband tile → heart →
  self tile — so the couple is wired in, not just the children; the Mei Ling → Sze Hao link
  moved out of the slot's loose 16 pt rectangle into the same anchored overlay as an
  anchored `GrandchildLineShape` that trims in over 0.4 s when the grandchild expands (and
  resets instantly on collapse). The face side's `person.text.rectangle` watermark switched
  from orange 4.5 % to black 12 % so the motif is actually visible.

- **Name card: home address, occupation, and a "Show me the way home" button** (user
  request). `FamilyMember` gained optional `homeAddress` and `occupation`; the demo owner
  lives at Blk 5 Banda Street (deliberately at the route-memory map's Chinatown
  coordinates, so the demo stays coherent) and is a retired schoolteacher. The card face
  shows both in an ID-style data zone (icon circle + small-caps bilingual label + value,
  hairline divider between rows). "Show me the way home · 带我回家" is now the card's single
  prominent action — it retracts the card and launches the Remember the Way activity;
  My Family and Put away demoted to a secondary bordered row. The launch logic moved from
  `ContentView.startActivity` to a shared `AppModel.startWayHome(openImmersiveSpace:dismissWindow:)`
  coordinator (guards against double-launch while the space is opening/open; the card
  just retracts if the person is already mid-activity), and the name-card window now
  receives `appModel` in its environment.

### Changed

- **Merged `origin/main` (580de07) into the local "Who am I?" work.** `CHANGELOG.md` conflicted
  because both sides opened a `## 2026-08-09` section — resolved by keeping both, ordered
  Added / Changed / Fixed / Removed. `Xcode_README.md` conflicted because upstream rewrote the
  run-instructions section the local branch had patched one line of; resolved toward upstream,
  whose rewrite already drops the stale "draw a circle / Summon / nest" description the local
  patch existed to fix. `SpatialRehab.xcodeproj/project.pbxproj` auto-merged (local file-ref
  changes vs upstream build-setting changes touched different regions). Also corrected
  upstream's "What you should see after launch" list, which still described **Who am I?** as an
  inline home-screen button — it is a window ornament as of the change logged under Added above.

### Fixed

- **`main` did not build after 580de07**: that commit's regenerated `SpatialRehab.xcodeproj`
  references `SpatialRehab/hand gestures.md`, a file that was never committed — `xcodegen`
  globs the source directory, so an untracked scratch file on one machine became a hard
  resource reference for everyone else (`CpResource … hand gestures.md` → **BUILD FAILED**).
  Fixed by re-running `xcodegen generate` against the actual tracked tree, which drops the
  dangling reference and picks up `WhoAmI/WhoAmIButton.swift` plus the `whoami-owner` imageset.
  Verified: `xcodebuild -scheme SpatialRehab -destination 'generic/platform=visionOS Simulator'`
  → **BUILD SUCCEEDED**. Worth knowing generally — never run `xcodegen generate` with untracked
  files sitting in `SpatialRehab/`, or commit the pbxproj without checking `git status` first.
- **Deployment target locked to visionOS 26.2**: `project.yml` (`options.deploymentTarget.visionOS`
  and the `SpatialRehab` target's own `deploymentTarget`) raised from `2.0` to `26.2` and
  `SpatialRehab.xcodeproj` regenerated via `xcodegen generate` (`XROS_DEPLOYMENT_TARGET = 26.2`,
  `SDKROOT = xros` in all 4 build configs). Matches the run target already documented in the
  `Xcode_README.md` rewrite below. `.skills/VISIONOS_AGENTS.md` Tech Stack OS line updated from
  `visionOS 26.0+` to `visionOS 26.2` to match.
- **`Xcode_README.md` draft reconciled**: resolved its two open TODOs — "Components" is the correct
  Xcode 16+ name (parenthetical notes it was "Platforms" in Xcode 15 and earlier); confirmed
  `project.yml`'s `sources:` entry is a directory reference (auto-discovery / globs, not an
  explicit file list), so the existing "drop file in `SpatialRehab/`, run `xcodegen generate`"
  guidance in "Adding new source files" was already correct — no hand-edit-`project.yml` warning
  needed.
- **`Xcode_README.md` rewritten for current `main`**: dropped the outdated “minimal scaffold /
  almost no product code” framing; documents the real app (baseline battery, Remember the Way,
  Daily Practice, caregiver dashboard, Who am I?, Making Tea scene kept but unwired), accurate
  source layout (`Models/`, `Views/`, `WhoAmI/`, wayfinding files), Info.plist AR keys, XcodeGen
  workflow, device vs Simulator guidance. Setup target kept as visionOS **26.2** (SDK + minimum
  deployment) as the team run target.

### Fixed

- **"Who am I?" no longer spawns duplicate card windows** (user report: "it shouldnt be
  able to create multiple windows of the same thing"). The name-card scene changed from
  `WindowGroup(id:)` to `Window("Who am I?", id:)` — on visionOS every `openWindow` on a
  window *group* creates another instance, while a `Window` is single-instance and the
  same call just brings the existing card forward. Pressing the button while the card is
  already up now refocuses it (and re-presents the face side for reorientation) instead
  of stacking copies.

- **Family tree connector lines never rendered** (user report with screenshot: "there is no
  lines connecting the family tree"). The tile-level `anchorPreference` was *replacing* the
  avatar anchors registered inside the same subtree — `anchorPreference` overwrites
  descendants' values where `transformAnchorPreference` merges — and since the connector
  overlay needs the husband's avatar anchor to place the heart, its guard failed and the
  entire overlay (heart + every line) silently drew nothing. Both registrations now use
  `transformAnchorPreference`. Same screenshot also showed the tile backgrounds not hugging
  the avatars (circles poking out the top) — the tile surface moved inside the button label
  so background and content can never disagree — and Mei Ling's relation text truncating,
  fixed by widening the child/grandchild text columns (130→138 / 110→118) plus
  `fixedSize(vertical:)` so bilingual relations wrap instead of clipping.

- **Family tree was cramped and clipping at the window edges; grandson now always visible**
  (user report with screenshot: "show the full family tree and space out the people a bit").
  The name-card window grew 660×760 → 900×960 (sized for three generations at readable
  tile sizes), spacing opened up (couple gap 40→56, children gap 20→32, generation gap
  40→56), and tiles scaled up (avatars 92/78/62 → 100/84/68). Sze Hao is now a permanent
  part of the tree under Mei Ling — the pinch-to-expand ritual, its `Grandchild · 孙子`
  placeholder capsule, the fixed-height slot, and `WhoAmISessionModel.showExpandedGrandchild`
  are all gone (tapping Mei Ling now plays her greeting beat like everyone else), and his
  connector line joined the main `ConnectorsShape` so the single trim reaches him last,
  after his mother. Face and greeting sides cap their content at 700 pt so they stay
  composed cards inside the tree-sized window; the face portrait scaled up to 220×264 to
  match.

- **Intermittent gray "shadow box" over the family tree during interaction** (user report
  with screenshot: "it looks a bit glitchy… a shadow box appearing occasionally when I
  interact"). Root cause: three stacked material layers (window glass → tree panel
  `.thinMaterial` → tile `.regularMaterial`) plus `.shadow` applied to material-filled
  shapes — visionOS materials sample the backdrop and don't nest reliably, and shadowing
  a material forces offscreen compositing that intermittently flattens to a gray plate.
  The card's `.ultraThinMaterial` is now the *only* material: the tree panel became a
  plain gradient wash, tiles/heart node/face chips/data zone use solid translucent white
  fills, the card-level orange `.shadow` and tile shadows are gone (remaining shadows sit
  on images/gradients only, which is safe), and the face's `.plusLighter` sheen layer now
  unmounts two seconds after its one-shot sweep instead of living over the glass forever.

- **Family tree: self tile highlighted in green, and an explicit back button** (user
  requests). The "You" tile's tint, border, avatar ring, glow, and `You · 您自己` label all
  switched from the family amber to green so "this one is me" reads at a glance — everyone
  else stays orange. A bordered `Back to my card · 返回名片` capsule now sits at the bottom
  of the tree (tapping your own tile still flips back too, but a labeled button is the
  affordance a disoriented person can actually find).

- **Card face: IC number, emergency contact, today's date, and an "About me" line** (user
  request; extras chosen from suggested options). `FamilyMember` gained `icNumber`,
  `emergencyContact`, and `aboutMe`. The NRIC (fictional `S1234567D` for the demo — never
  ship a real one) joins the birthday/age chips; "IF YOU NEED HELP · 求助" (call Mei Ling)
  became a third data-zone row, with the zone's rows refactored into a data-driven
  `ForEach`; a reality-orientation strip under the header shows "Today is Saturday, 9
  August · 星期六" bilingually (recomputed per render — the card is short-lived, so no
  midnight-refresh plumbing); and a serif-italic reminiscence line (gardening, taiji,
  laksa) sits under the data zone for person-centred warmth.

- **"Who am I?" no longer requires drawing a circle** — that gesture-summon ritual (draw a
  circle over a glowing nest to open the name card) wasn't the intended interaction and was
  removed: `WhoAmIView.swift`, `NestView.swift`, and `CircleDrawCanvas.swift` are deleted,
  along with `WhoAmISessionModel`'s circle-quality math (`beginStroke`/`continueStroke`/
  `endStroke`/`evaluateCircle`/`circleClosureHint`/`pathLength`) and the `drawPoints`/
  `glowProgress`/`.drawing`/`.nest` state that only existed to support it. `ContentView`'s
  "Who am I?" button now calls the session directly (`whoAmISession.present()`) and opens
  the `name-card` window straight away — tappable at any point, no separate summon screen.
  The `"who-am-i"` `WindowGroup` is gone from `SpatialRehabApp.swift`; `whoAmISession` is now
  shared into `ContentView`'s environment instead. `Phase` simplified to
  `closed`/`presenting`/`open`/`puttingAway`. The actual name card, family-tree flip, and
  greeting-video flow (`NameCardView.swift`, `FamilyTreeView.swift`) are unchanged.

### Removed

- **Hummingbird volumetric demo** (merged in from `szehao-id-card`): `HummingbirdVolumeView.swift`,
  `hummingbird_anim.usdz`, its `WindowGroup(id: "hummingbird")` scene in `SpatialRehabApp.swift`,
  and the "Hummingbird" button on both `ContentView` screens. `project.yml` / `SpatialRehab.xcodeproj`
  minimum deployment lowered back from visionOS **26.0** to **2.0** — `.manipulable()` (the reason
  for the earlier raise) was only used by this view.

## 2026-08-08

### Added

- **Simplified the control panel while stepped inside Remember the Way, and made it
  draggable** (user report: "when i click on step inside it doesnt allow me to move unless
  i click on im ready... it should just show the button to back to table and also allows me
  to shift this window to the side or wherever i want").
  - `RouteMemoryView.swift` (`controlPanel`) — the `exercise.state`-driven `controls` block
    (which still rendered a disabled "I'm ready" button while inside, since `exercise.state`
    stays `.studying`) is now skipped entirely while `insideMode`; the panel shows only its
    prompt text and "Back to table" + the voice toggle, matching what's actually available.
    The disabled "I'm ready" button sitting there was likely the real cause of "can't move
    unless I click I'm ready" — it read as a required step even though it was inert.
  - New `controlsAnchor`/`controlsHandle` entities — the panel attachment now parents under
    `controlsAnchor` instead of attaching to the scene root directly, and a small metal grab
    bar (`buildControlsHandle()`, same visual language as the table's own handle) sits just
    below it with its own `CollisionComponent`/`InputTargetComponent`. A new
    `DragGesture().targetedToEntity(controlsHandle)` moves `controlsAnchor` (and the panel
    with it) directly under the hand — a dedicated handle rather than making the whole glass
    panel draggable, so dragging can't be confused with, or steal touches from, the panel's
    own buttons.
  - Verified with a temporary auto-triggering `.task` (this sandbox has no tap automation
    for the visionOS Simulator, so "Step inside" couldn't be tapped through directly):
    screenshotted the panel post-step-inside showing only the prompt and "Back to table",
    with the new drag handle visible underneath. Both temporary triggers fully removed
    afterward.

- **Main window now dismisses entirely during Remember the Way**, instead of floating an
  empty glass pane behind the holographic table (user report, with a screenshot: "when i
  click the navigation button it currently shows this empty window here"). Previously
  `ContentView.inActivity` rendered `EmptyView()` while `.inActivity`, but the window chrome
  itself — the blank glass rectangle — still hung there next to
  `RouteMemoryTableView.controlPanel`, which already carries all the real guidance.
  - `SpatialRehabApp.swift` — the main `WindowGroup` now has an explicit
    `id: SceneID.main` (new `SceneID` enum, same pattern as `ImmersiveSpaceID`); a
    `WindowGroup` with no id can't be targeted by `dismissWindow`/`openWindow`.
  - `ContentView.startActivity()` calls `dismissWindow(id: SceneID.main)` right after the
    immersive space opens successfully and `phase` flips to `.inActivity`.
  - `RouteMemoryTableView.onDisappear` calls `openWindow(id: SceneID.main)` unconditionally,
    covering every way the immersive space can close: the "Done" button (phase already
    `.finished` by then), a system/gesture dismissal (phase reset to `.welcome` in the same
    handler), or a step-inside interruption.
  - Verified with a temporary auto-triggering harness in `SpatialRehabApp.swift` (this
    sandbox has no tap automation for the visionOS Simulator, so "Start"/"Done" can't be
    tapped through directly): screenshotted the window present on launch, gone once the
    immersive space opened, and back once it closed. Harness fully removed afterward.

- **Professional `README.md`** for the repo root — project pitch, feature tour, architecture
  overview, setup instructions, team roster, and roadmap, styled after a teammate-approved
  reference README. Screenshots captured via the simulator (`assets/screenshots/`); logo
  exported as a standalone `assets/logo.svg` mirroring the in-app mark.
- **Two-step intro flow** (`BaselineAssessmentView`): the brand screen (logo, name,
  description) is now its own step with a "Next" button, separate from "A Few Quick
  Activities" — previously both were stacked on one screen. Local `IntroStep` enum, not
  part of `BaselineAssessmentSession.Phase` (pure intro sequencing, nothing worth persisting
  or resuming).
- **Redesigned the intro logo mark three times**, per direct feedback ("i dont like this
  home logo"), then ("i still dont like the logo"), then ("i want some geometric shape or
  something"): house-silhouette badge → three offset layered panes (read as an indistinct
  blob at intro size) → an orbiting-node mark (ring, center dot, glowing node — the user's
  pick from a first round of four options) → the final **faceted hexagon** — six triangular
  facets at varying blue-over-indigo opacity around a shared center, brightest at the
  upper-left to read as a cut gem catching light, drawn with `Canvas` (the same primitive
  `ClockDrawingView` already uses) rather than stacked `Shape`s. Chosen from a second round
  of four geometric-specifically options (faceted hexagon, isometric cube, faceted triangle,
  overlapping rotated squares) after the user asked for "some geometric shape." Each round
  presented rendered-preview mockups before implementing. `assets/logo.svg` kept in sync
  with the in-app mark at every step.

### Removed

- **App focused to a single activity — Remember the Way**: deleted Touch the Dots, Walk to the Bakery, and Find Your Way Home (files, pbxproj entries, `ActivityKind` routing, `SpatialStreetCache` warming, `DemoStreetPanorama.jpg`). Shared route coordinates moved from `FindHomeExercise` to a small `DemoRoute` enum in `NeighborhoodWorld.swift`; unused `NeighborhoodController` removed. Welcome screen is now a single calm Start into the exercise (one thing on screen — finally matching our own patient-mode rule). Prior activities remain in git history if ever wanted back.

### Added

- **Removed the flat window's leftover text during Remember the Way entirely** —
  `ContentView.inActivity` is now `EmptyView()`. A generic "Look around you" (the previous
  fix) was still a second surface competing for attention with the immersive control panel,
  which already shows everything needed; now the flat window shows nothing while the person
  is in the exercise.
- **Branded intro screen** (`BaselineAssessmentView.introContent`, the first thing shown on
  every launch): added a logo mark, the project name, and a short description above the
  existing "A Few Quick Activities" section, so the very first screen reads as a real app
  rather than jumping straight into "let's do some activities" with no context. The logo is
  a house silhouette on a blue-to-indigo gradient badge, built from SF Symbols + SwiftUI
  shapes rather than an imported SVG — Xcode can import a real SVG as a scalable vector
  asset, but authoring one by hand with no design tooling to preview it wasn't a good trade;
  this gets the same crisp vector scaling entirely in code.
- **Combined the two competing "what do I do now" panels** during Remember the Way. The
  flat window (`ContentView.inActivity`) had its own static "Look at the table / Study the
  glowing route…" text that never updated as the exercise progressed, floating alongside
  the immersive space's own control panel (`RouteMemoryTableView.controlPanel`), which
  already shows the real, phase-accurate prompt ("Take your time…", "Tap the corners…",
  score feedback) plus the actual buttons — two instruction surfaces competing for
  attention, one of them stale. The flat window now just says "Look around you" and defers
  entirely to the immersive panel as the single source of in-the-moment guidance.
- **Patient-first pass on Remember the Way** (dementia-perspective audit):
  - **Voice guidance** — `VoiceGuide.swift` (`AVSpeechSynthesizer`, en-SG voice, slowed rate) speaks every stage: study intro, draw instructions, feedback, step-inside guidance, and arrival ("You've reached home. Well done."). Speaker toggle on the panel; on `AppModel` for reuse by other activities.
  - **No more countdown** — study is fully self-paced ("Take your time. Press I'm ready when you know the way"); study duration recorded invisibly (`studySeconds`); pause/resume machinery removed.
  - **Pinch-toggle walking** — pinch the street once to walk, again to rest (was: sustained pinch-hold, fatiguing for elderly hands); auto-stops with a spoken arrival at the end of the route.
  - **Tap-the-corners draw mode (new default)** — the route's decision corners (≥25° heading change, capped at 7) appear as dots; the patient taps them in order and the real route reveals segment by segment (errorless, motorically gentle). Wrong-order taps pulse softly and are counted invisibly; feedback banded on wrong taps. Free tracing remains as the harder mode via a caregiver toggle in Adjust.
  - **Real-time ink for free tracing** (user feedback) — the trace renders as a live screen-space stroke directly under the finger (same fixed-camera overlay trick as the route animation) instead of chunky decimated MapKit polyline updates; coordinates still captured underneath for scoring.
  - **Calm grab returns** (user: grabbing yes, but intuitive) — visible metal grab bar under the table's front edge (gaze-glow affordance): while held, the table *eases* toward the hand (12 ms lerp loop — heavy-object feel that filters elderly hand tremor), never tilts or rotates, surface height clamped 0.05–1.35 m and lateral reach 0.45–2.3 m; on release it magnetically settles to the nearest sensible height (table or floor) over 0.45 s. Gesture scoped strictly to the bar; Adjust buttons kept as the accessible alternative; handle hidden in life-size mode.

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

### Added

- **Real greeting video for the grandson**: `szehao_greeting.mov` (9.4 MB, 3.7 s, 1080p HEVC) bundled under `WhoAmI/`; pinching Sze Hao now plays the actual video via `AVKit` (`GreetingVideoView`) — the greeting auto-closes when playback genuinely ends (`didPlayToEndTime`, 30 s safety net) instead of the fake 4 s progress loop; fake progress bar hidden for real videos. `FamilyMember` gained `videoFileName`/`videoURL` so more family videos are one-line additions.

### Fixed

- **Family tree glitching** (`szehao-id-card`): three compounding causes — the card's `rotation3DEffect` flip z-fought the window's glass material on device (and pre-mirrored the tree for the whole turn); person cards stacked an extra `.hoverEffect()`/`.contentShape(.hoverEffect,…)` on Buttons that already have their own gaze highlight (two competing glows shimmering); and the tree re-laid-out when the grandchild expanded, detaching the stem connector lines. Now: the face/tree sides **crossfade** (calmer for dementia users too), the duplicate hover modifiers are removed (button border shape still shapes the highlight), and every child column reserves a fixed 185 pt grandchild slot so nothing moves when Sze Hao fades in. `name-card` window default size raised to 660×760 so the tree fits without compression.

### Added

- **Who am I? name card** (`szehao-id-card`): dementia-friendly identity ritual. Welcome **Who am I?** opens nest + circle-draw pad (Simulator drag loop or **Summon** button). Completing an approx circle presents a glowing NRIC-style card (Lim Chio Bu / 林招母, birthday, emoji portrait) in a second window. **Family** flips to a soft yellow tree (Ah Pek + three children; Sze Hao under Mei Ling). Pinch photo → greeting turn with bilingual relation caption; **Sze Hao** plays a 4s demo line then auto-closes. **Put away** flies the card back to the nest. Files under `SpatialRehab/WhoAmI/`; windows `who-am-i` + `name-card`. `Xcode_README.md` lists the welcome entry.

- Hummingbird volumetric window: `hummingbird_anim.usdz` added to the app bundle, a new `HummingbirdVolumeView.swift` displays it via `Model3D` with `.manipulable()` so it can be grabbed, moved, and rotated by hand, and a second `WindowGroup(id: "hummingbird")` with `.windowStyle(.volumetric)` declares the scene in `SpatialRehabApp.swift`. The "Get Started" button in `ContentView.swift` now opens it via `openWindow(id:)`.

### Changed

- `project.yml` minimum deployment raised from visionOS **2.0** to **26.0** — required by the `.manipulable()` gesture API used for hand interaction with the hummingbird model. This narrows device/OS support versus the prior floor; revisit if older visionOS targets become a requirement.

### Removed

- **Yishun map / VR walk** from this branch (`szehao-id-card`): `SpatialRehab/YishunWalk/`, welcome walk buttons, immersive space, traffic-light volume, and hands-tracking usage string. That work stays on `szehao-mapkit-yishun-walking`.
- **mac2visionOS / Mac Link** stack for the hackathon: SPM dependency, multiplatform macOS target, Bonjour/local-network Info.plist keys, sandbox network entitlements, and bubble host/controller/smoke/stability UI files. Local dev is **visionOS Simulator only**.

### Fixed

- (2026-08-07) `ContentView.startImmersiveSpace()` silently did nothing if
  `openImmersiveSpace` returned `.userCancelled` or `.error` — the screen looked identical
  to a tap that hadn't registered at all, with no way to tell them apart. Now shows a
  message on-screen for the cancelled/error cases and disables the button while opening.

### Added

- (2026-08-08) Caregiver progress dashboard, plus the history-tracking fix it depends on.
  - `SpatialRehab/Models/BaselineResultsStore.swift` — rewritten from single-overwritten
    values to **appended history arrays** per game. This was the top-priority known gap:
    every prior session's result was silently discarded the moment the next one saved,
    which undercut the entire "baseline to compare against" premise. `loadXResult()`
    accessors are unchanged in signature (now return `.last` of the history); new
    `loadXHistory()` accessors expose the full run. Migration caveat: old single-value
    `UserDefaults` data doesn't decode as the new array shape, so it's silently dropped —
    documented in the file and in `Docs/BaselineAssessment_Design.md`.
  - `SpatialRehab/Views/ScoreTrendChart.swift` — two reusable Swift Charts components:
    `ScoreTrendChart` (0–100% line chart, six games reuse this) and
    `MillisecondTrendChart` (reaction time's raw-ms history, which doesn't normalize to a
    percentage).
  - `SpatialRehab/Views/CaregiverDashboardView.swift` — the actual caregiver-facing
    screen: an overview card (session count, last-played date), one trend chart per
    scoreable game (reusing each game's existing identity color from
    `BaselineResultsDebugView` for visual continuity), and a horizontally-scrolling
    clock-drawing thumbnail gallery (still unscored, but now browsable over time instead
    of only the latest sketch). A "Raw Data" toolbar button opens the existing
    `BaselineResultsDebugView` as a nested sheet.
  - `ContentView.swift` — primary action ("View Progress") now opens
    `CaregiverDashboardView` directly; the dev raw-data view is no longer reachable
    straight from the home screen, only via the dashboard's toolbar.
  - Verified by temporarily seeding 6 weeks of synthetic per-game history (multiple
    `BaselineResultsStore.save()` calls with backdated `completedAt`/`capturedAt` values)
    to confirm the trend charts render real multi-point lines and both axis-label styles
    (percent, milliseconds) correctly — this sandbox can't interactively tap through the
    games, so real gameplay data wasn't available to verify against. Seeding code was
    then fully removed; the simulator was uninstalled/reinstalled afterward to clear the
    synthetic data before finishing.
- (2026-08-08) Removed all emoji from the UI (`ContentView.swift` had the only three:
  a wave, a clipboard, a sprout). The wave was just decorative punctuation on the
  greeting text and was dropped; the clipboard and sprout were standing in for icons, so
  they became `Label`s with SF Symbols (`checklist`, `leaf.fill`) instead — consistent
  with the SF Symbol icon language already used everywhere else in the app.
- (2026-08-08) Tried and **reverted** a custom window redesign (`.windowStyle(.plain)` +
  a custom gradient background, replacing the default system glass chrome). Reverted per
  direct feedback ("don't like the current design") after one round: the light gradient
  first attempted broke text legibility everywhere, because every screen's `.primary`/
  `.secondary` text was relying on the system's default dark glass panel for contrast,
  not any background of its own — worth remembering if this is attempted again: any
  custom window background needs to either match the old backdrop's darkness or every
  screen's text styling needs auditing at the same time, not after.
- (2026-08-08) Expanded the baseline battery from 4 to 8 games and redesigned the
  post-battery home screen.
  - `SpatialRehab/Models/DigitSpanResult.swift`, `TrailMakingResult.swift`,
    `OrientationResult.swift`, `ReactionTimeResult.swift` — new result models.
  - `SpatialRehab/Views/DigitSpanGameView.swift` — sequential digit flash, then tap back
    in order on a number pad; scored by position (partial credit), not all-or-nothing.
  - `SpatialRehab/Views/TrailMakingGameView.swift` — tap 8 scattered numbered dots in
    order; out-of-order taps do nothing visible, just counted silently as errors.
  - `SpatialRehab/Views/OrientationGameView.swift` — day-of-week/time-of-day/month
    questions computed live from the current date (not static content, unlike the other
    games' placeholder content); deliberately excludes the classic MMSE "what season is
    it?" question since seasons don't map onto this product's tropical/Singapore context.
  - `SpatialRehab/Views/ReactionTimeGameView.swift` — shape flashes at a random position
    after a random delay (prevents anticipation), tap it, 3 trials; opens the battery as a
    literal warm-up per the product-vision doc's "Touch the dots" framing.
  - Battery reordered to group related domains: reactionTime → orientation → wordMemory →
    digitSpan → patternMatching → trailMaking → arithmetic → clockDrawing. None of the 4
    new games feed `GameRecommendationEngine` — deliberately out of scope, see Docs.
  - `BaselineAssessmentSession.Phase` gained `CaseIterable` + a `gameCount` computed
    property (`allCases.count - 2`, excluding intro/summary) so nothing hardcodes "8".
  - `BaselineResultsStore` gained `completedGameCount()` and save/load for the 4 new types.
  - `BaselineResultsDebugView` gained 4 new sections (reaction time gets a bar chart of
    raw ms readings instead of a gauge, matching clock drawing's precedent of not forcing
    an arbitrary score where one doesn't naturally exist).
  - `ContentView.swift` redesigned per a reference mockup: a single centered card with a
    time-aware greeting, a section label, a subtitle, one primary action, and a real
    "X of 8 activities completed" stat (via the new `completedGameCount()`) — adapted into
    this app's existing rounded-rect/`regularMaterial` visual language rather than the
    mockup's literal dashed-border/monospace wireframe styling. The primary action still
    opens the dev results view, honestly labeled as a dev preview, not dressed up as a
    real patient activity that doesn't exist yet.
- (2026-08-08) Wired `GameRecommendationEngine` into `BaselineResultsDebugView` — a new
  "Recommended Focus (Dev)" section shows each scored domain's priority as a bar chart
  (reusing that domain's game's identity color: memory=blue, numeracy=teal, executive
  function=purple) plus the top-priority domain's recommended games with their summaries.
  Deliberately **not** shown to the patient yet: `StimulationGameCatalog`'s entries
  ("Virtual Hawker Centre", "What Comes Next?", etc.) don't have real game screens built,
  so recommending one to a person with dementia would point at something not tappable —
  fine to preview here, not fine to promise on the patient-facing summary screen. Promote
  once those games exist. Added `CognitiveDomain.displayName` for the section's labels.
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
