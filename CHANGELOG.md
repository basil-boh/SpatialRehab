# Changelog

All notable changes to this project are recorded here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).  
Coding agents: see `AGENTS.md` — update this file whenever you edit the repo.

## 2026-08-09

### Added

- **Coffee rebuilt around the assets' real anatomy** (user: pour physics "not there", use the USDZ assets properly; anatomy discovered by inspecting the USDCs + `.articulation.json` manifests):
  - Streams now emit from each vessel's **named spout entity** (`pour_spout` on the kettle and milk jug) instead of a bounds guess; pour threshold eased to ~54°.
  - The mug's **own internal `coffee` liquid mesh** (prismatic fill joint in the asset) rises and tints through water → kopi-o → kopi-c — the fake overlay cylinder is gone; the kettle's `water_column` and the jug's `milk` mesh **visibly deplete** as they pour.
  - The sugar bowl's **hinged lid swings open** when tilted and its **five real `sugar_cube` entities tumble out** with physics — cubes that land in the mug dissolve into the coffee (2 completes the step); misses stay scattered on the table. The coffee tin's lid opens for the grounds.
  - **Steam wisps** curl off the mug once the hot water is in; lids close on settle; reset restores cubes, lids, and fill levels.
- **Real Singapore Mahjong rules** (friend's review: game wasn't playing to the actual rules; full SG rules provided by user):
  - `MahjongRules.swift` — pure rules engine over the SG148 taxonomy (bamboo/dots/char suits, dragons + winds as honors, flowers/seasons/animals as bonus): backtracking hand decomposition for the **real win condition — four sets (chows/pongs) plus one eye**, winning-tile search (tenpai detection), chow-option enumeration, and an isolation-based discard suggester.
  - **Flowers/seasons/animals behave per the rules**: never held — they fly to the exposed area with a spoken explanation and a replacement is drawn from the far wall (patient's automatic; opponents expose theirs after the deal).
  - **Claims**: after every opponent discard the engine checks the patient's hand — **Mahjong! / Pong! / Chow!** buttons appear (chow only from Mei Mei on the left, per the rules), 12 s window then auto-pass, claimed melds animate to the exposed area and count toward the four sets. Win-on-discard supported.
  - **Kind but honest**: the deal is a verified genuine tenpai (three sets + eye + waiting pair), draw kindness ramps toward actual winning tiles, opponents preferentially feed pongable tiles, and Mei Mei may throw the winning tile after turn three. The final reveal lays the real 14-tile hand face-up: "Mahjong! Four sets and a pair."
  - Consciously deferred: kongs, fan scoring, banker/prevailing-wind rotation, pay-all scenarios (documented for future work).
- **Authentic wall procedure + no racks** (user's detailed corrections, Q&A confirmed pong+chow and accept-any-draw):
  - **Strict shared draw order**: top tile then bottom tile of each stack, marching around the wall from the patient's right — the glow marks the true next-in-order tile and the three opponents visibly draw in exact sequence; the patient may take any wall tile (chosen house rule, zero friction).
  - **Kindness went invisible**: instead of glowing arbitrary lucky tiles, the engine silently swaps two face-down wall tiles so the next-in-order tile is a winning one — physically undetectable, procedurally perfect.
  - **Racks removed** (all four seats): tiles stand directly on the felt, as at a real home table; free self-arrangement of the hand unchanged.
  - **Pong-assist**: the claimable discarded tile itself glows in the river while the Pong/Chow/Mahjong buttons and voice prompt run; claimed melds remain open at the side of the hand.
  - **Hand drop pad**: a soft green pad ("Put tiles here") beside the hand row — a drawn wall tile dropped there becomes the draw AND auto-slots into the first free position in the row; the patient's own tiles dropped there re-join the neat line. Stray wall tiles now glide back to their wall slot instead of lying loose.

### Fixed

- **Discards not deducting** (user report): the discard target was a small invisible rectangle over the glow pad — tiles thrown anywhere else in the middle silently stayed in the hand. Now any central table area accepts the throw (like a real toss to the middle; the glowing pad remains just a suggestion), and throwing before drawing gets a spoken rules correction ("First take the shining tile from the wall") with the tile returning to the row.
- **Smoothness pass** (user: "still feels a little jarring"):
  - `VoiceGuide` now **queues** utterances instead of cutting the current sentence off mid-word (interrupt only on explicit `interrupting: true`); short pre-utterance breath added. Benefits every activity.
  - **Pour flow ramps with tilt** (0…1 per vessel, eased both directions): the stream's width, arc speed, splash rate, grain count, and the pour-hiss volume all scale with how far the vessel is actually tipped — no more binary on/off at a threshold angle.
  - Released items **settle with distance-scaled travel time** (0.3–0.85 s) instead of a fixed-speed glide, so nothing reads as teleporting.
  - Ghost demos **fade in and out** (~0.25 s opacity ramps) instead of popping.
- **Mahjong v5 — proper four-seat table** (per the newly installed `.claude/skills/mahjong-ui-components` skill; the user's download link 404'd so the skill was installed from their pasted content):
  - Standard tile geometry (3.4 cm height normalization, 2.8 cm spacing), square table with per-side rims, **four racks and four seats** — the patient (East) plus three named opponents: **Ah Hua** (right), **Uncle Lim** (across), **Mei Mei** (left), each with 13 standing face-away tiles.
  - **Hollow-square wall**: double-stacked columns on all four sides, sized to exactly the 96 tiles remaining after four deals — assembled from the wash in waves.
  - **Per-seat 3×6 discard rivers** oriented to their owners; the patient discards into their own glowing river pad (replaces the shared center circle); melds sort to the patient's far right (skill convention).
  - **Humanized AI turns** (skill: 0.6–1.5 s + 5 mm hover): each opponent visibly draws from their side of the wall, hesitates over a tile, and discards to their river with a clack; their hand closes the gap. AIs never win.
  - **Rack placement fix** (user report): dropping a tile on the wooden rack strip now seats it into the hand line at that spot; patient hand tiles keep the skill's −15° ergonomic pitch.
  - Consciously NOT adopted from the skill: Riichi scoring, steals (Pon/Chii/Kan), dead wall, anti-cheat culling — the SG148 set and the dementia audience keep rules at "two sets wins," errorless.

- `NSHandsTrackingUsageDescription` in `Info.plist` — required privacy text for the new `HandWashTracker` (ARKit `HandTrackingProvider`) that feeds real palm positions to the mahjong wash phase.
- **Mahjong "full RealityKit" naturalness pass** (built via parallel agent workflow + orchestrator integration):
  - `MahjongAudio.swift` — fully procedural table soundscape (44.1 kHz buffers synthesized at setup): tile **clack** (noise burst + 1.8–2.2 kHz ping, 5-buffer/5-node round-robin pool so rapid clacks overlap), softer pick-up **click**, two-note meld **chime** (E5→A5), and a seamless 2 s **wash rumble** loop (low-passed noise bed + 48 randomized micro-clacks, crossfaded seam).
  - `HandWashTracker.swift` — ARKit `HandTrackingProvider` per the repo skill: exposes live palm positions (wrist→middleFingerMetacarpal offset), silent no-op on simulator/denied auth.
  - **Wash with your real hands**: during the opening wash the tile carpet flees the patient's palms (repulsion within 15 cm at table height) over a gentle ambient swirl fallback, with wash rumble + throttled clacks while pushing.
  - Sounds wired through the whole game: wall-building waves clack, deal clicks per tile, draw landing clack, meld chime, every discard clack.
  - **Free rack arrangement**: the hand no longer auto-sorts — the drawn tile lands at the rack's end like a real draw, and any hand tile re-slots at whatever position it's released (index from drop x), exactly how experienced players manage their rack.
- **Mahjong v4 — free placement + crash-proof ceremony** (user: still couldn't grab freely, fixed slots are anti-mahjong, table looked bugged):
  - Root cause of the mess: the whole ceremony ran inside RealityView's make closure; SwiftUI task cancellation collapsed every stagger to zero and stranded the wash pile. Ceremony now runs in `.task` with cancellation-guarded pauses and a **deterministic instant-finish** (every tile's final transform precomputed up front — on any interruption the table completes itself correctly).
  - **Zones, not slots**: every tile always grabbable and stays wherever it's placed (settled upright on the felt, clamped to the table, clack on landing). Bringing ANY wall tile to your side of the table = your draw; dropping one of your tiles in the circle = your discard; everything else just lies there like a real table. No snap-backs anywhere.
  - Extraction reverted to `clone(recursive:)` — the path that provably preserves tile face materials (the white-blob tiles came from the detach path).
  - Hand-tracker start no longer blocks the ceremony (fires in a background task; palms join the wash whenever authorization lands).

- **"Play Mahjong Pairs" activity** (third activity) — find-the-twins matching with the generated SG148 mahjong assets:
  - Twelve real tiles (6 pairs from high-contrast faces) extracted from `mahjong_full_set_sg148.usdz` by prim name via the bundled `.tiles.json` manifest, cloned, normalized, and dealt onto a felt-topped table in a shuffled grid.
  - **Physical matching**: tiles are picked up with the system grab and set down beside their twin; matched pairs lift and fly side-by-side onto the real `mahjong_tile_rack`; wrong pairings get a gentle spoken redirect and settle back to their slot; loose drops settle home.
  - **Stuck support**: after 18 s without progress, cyan rings glow under one unmatched pair with a spoken hint (hint count recorded invisibly, alongside wrong attempts and duration).
  - Voice intro/praise/celebration; panel shows pairs progress; simulator smoke test confirms tile faces render and extraction works.
- **Reworked to full mahjong vs the computer** (user feedback: sparse pairs looked wrong — missing manifest faces silently dropped pairs; wants all 148 tiles + an opponent):
  - All 148 tiles dealt onto a proper table: patient's rack with 13 standing sorted tiles (dealt as 4 pairs + 5 singles — near-melds from the start), computer's rack across the table with tiles facing away, and **walls of the remaining 122 tiles** (three rows each side + far rows, backs to the center).
  - Turn loop: the next wall tile glows → patient physically picks it up → snaps into the sorted hand → voice evaluates ("that matches yours — keep it!") → three-of-a-kind **melds slide forward automatically** → discard by carrying any hand tile to the glowing center circle → the computer visibly draws and discards → repeat. **Two melds = "Mahjong!"** win.
  - Wall draws invisibly rigged toward the patient's pairs; discard suggestion glows (their choice still free); wrong drops counted invisibly; faces now driven entirely from the runtime manifest (no hardcoded face names — the earlier missing-tiles bug is structurally gone).
  - Note: the dice seen on the rack in device testing are modeled into the `mahjong_tile_rack` asset itself.
- **Mahjong v3 — proper ritual + fixed pickup** (user: couldn't grab tiles; wants the opening shuffle and a proper look):
  - **Grab fix**: every tile re-wrapped with a base pivot and a hit box computed from its real bounds (`visualBounds`-derived collision) — the v2 pivot-offset boxes floated away from the visuals, which is why tiles couldn't be picked up.
  - **Opening ceremony**: all 148 tiles spill face-down into the center → traditional **wash** (two slow swirls, voice: "First, we wash the tiles — just like at home") → tiles fly into **four proper walls, two tiles high, lying face-down** → animated deal of 13 to each rack.
  - **Agency**: the whole hand is always grabbable; any of the six nearest top wall tiles may be drawn (glow = suggested lucky tile, rigging preserved); stray wall tiles tuck themselves back; melds and discards now lie **face-up flat** in the middle like a real game; wooden rim added around the felt.
  - Face-up/face-down orientations are single constants (`faceUp`/`faceDown`) in case the tile pivot proves flipped on device.
- **Ceremony cleanup** (user: "tiles just lying around, not smooth"): root cause was 148 tiles sent at 122 wall slots — 26 orphans stayed scattered mid-table. Now every tile's destination (hand/opponent/wall) is decided **before** any placement, wall slots extend to exactly match the wall count, the wash is a tidy non-overlapping face-down carpet that rotates gently (no interpenetration/z-fighting), and all flights run in staggered waves (walls 10-per-wave, deal tile-by-tile) instead of 148 simultaneous animations.

## 2026-08-08

### Added

- **"Make a Cup of Kopi" activity** — guided ADL (activity of daily living) coffee-making on a virtual wooden table, using the generated USDZ assets (water kettle, coffee tin with scoop, sugar bowl, milk jug, coffee mug, teaspoon; auto-normalized to real-world sizes from their bounds):
  - Five-step guided sequence (hot water → coffee → sugar → milk → stir) with spoken instructions and praise per step; wrong picks get a gentle spoken redirect and an invisible metric (`CoffeeExercise`).
  - **Floating tags on every asset** (name + role, orange-highlighted and enlarged on the current step) so the patient always knows what each thing is — a fully guided process.
  - **3D step demonstrations**: a translucent ghost of the current item lifts, tips over the mug, and returns, looping until the patient taps the real item; the real pour shows a colored stream and the mug's liquid visibly rises and darkens (water → kopi-o → kopi-c) with a stirring finale.
  - Glow ring under the current item, cyan; tap targets padded around each asset's bounds.
  - Welcome screen offers both activities again (`ActivityKind.routeMemory` / `.coffee`); coffee runs in mixed immersion (patient's real room).
- **Physical pouring rework** (user: "actually hold and pour… like the real world"; deployment target raised **2.0 → 26.0** for `ManipulationComponent`):
  - Items are genuinely **picked up** with the system's natural grab (pinch-hold, follows the wrist, hand-to-hand transfer); tilting a held vessel past ~63° emits physics droplets/grains from its lip (position + velocity follow the vessel's actual tilt direction; dynamic bodies, ≤70 live, 30 Hz simulation loop).
  - Droplets that land in the mug's catch volume fill it (level + color mix computed from actual caught counts: water → kopi-o → kopi-c); misses bounce on the table's static collision and fade. Steps complete when enough of the *right* ingredient is really poured in (water 22, coffee 14, sugar 10, milk 16).
  - **Stirring is real**: hold the teaspoon in the mug and move it in circles — angular travel is accumulated (2 full turns completes).
  - Wrong-ingredient pours get one gentle spoken note per step and an invisible metric; released items **settle gently upright onto the table** (clamped to its surface) instead of floating or toppling — errorless physicality.
  - Ghost demos, floating tags, glow ring, and voice guidance all retained; tap-to-pour removed.
- **Realistic pour rendering** (user: droplet beads ≠ liquid):
  - `PourEffects` — water/milk render as a **continuous ballistic stream**: tapered 14-segment tube along the real parabola from the vessel's lip (velocity from actual tilt), translucent PBR water / opaque cream milk; splash droplets pool at the impact point; fill accounting switches to stream-ticks-on-target (water 70, milk 50).
  - Coffee/sugar pour as dense fine grains (3 mm, 4/tick) with physics, replacing pebble-sized drops.
  - Mug liquid is now **translucent PBR** while it's just water, turning opaque as coffee/milk mix in.
  - `PourSound` — procedural pouring hiss (looped filtered brown noise via `AVAudioEngine`), ramped on while a stream flows.

### Removed

- **App focused to a single activity — Remember the Way**: deleted Touch the Dots, Walk to the Bakery, and Find Your Way Home (files, pbxproj entries, `ActivityKind` routing, `SpatialStreetCache` warming, `DemoStreetPanorama.jpg`). Shared route coordinates moved from `FindHomeExercise` to a small `DemoRoute` enum in `NeighborhoodWorld.swift`; unused `NeighborhoodController` removed. Welcome screen is now a single calm Start into the exercise (one thing on screen — finally matching our own patient-mode rule). Prior activities remain in git history if ever wanted back.

### Added

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
