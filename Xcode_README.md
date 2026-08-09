# SpatialRehab — Xcode / visionOS setup

This repo is a **visionOS app** for a hackathon / product sprint: help people with early-stage dementia practice cognitive skills and relearn **daily routes** in spatial computing (errorless learning, no patient-facing scores).

`main` already has substantial product code — not an empty scaffold. First launch runs an 8-game cognitive baseline; afterward the home screen opens **Remember the Way**, plus **Daily Practice**, a **Caregiver Dashboard**, and **Who am I?**. Product overview and design rationale live in [`README.md`](README.md).

> **Primary run destination for spatial / hand work is a paired Apple Vision Pro.** The Simulator is fine for UI, the baseline battery, dashboard charts, and most of Remember the Way. True hand tracking and world-sensing (Making Tea / `HandProximityTracker`) need the device.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **Mac** | Required (Xcode only runs on macOS) |
| **Xcode 26.2+** | Must ship the **visionOS 26.2 SDK**. A beta seed is fine if it is 26.2 or newer |
| **Apple ID** | A **free** Apple ID is enough for both the Simulator **and** a real Apple Vision Pro. A paid account is only needed for TestFlight / App Store distribution |
| **Apple Vision Pro** | Available to the team — see [How to run on device](#how-to-run-on-device--primary-for-arkit) |

Install Xcode from the Mac App Store, or a beta seed from [Apple Developer Downloads](https://developer.apple.com/download/applications/).

After install, open Xcode once, accept the license, and let it install additional components if prompted.

**CLI tip:** if `xcodebuild` only finds Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

If you are on a beta seed installed alongside stable Xcode:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

---

## How to open the project

### Option A — Finder (easiest)

1. Clone or download this repo.
2. Open the folder in Finder.
3. Double-click **`SpatialRehab.xcodeproj`**
   (not the `SpatialRehab` folder next to it — open the file that ends in `.xcodeproj`).

### Option B — Terminal

```bash
open SpatialRehab.xcodeproj
# or, for a beta seed:
open -a Xcode-beta SpatialRehab.xcodeproj
```

### Option C — From inside Xcode

**File → Open…** → select `SpatialRehab.xcodeproj` → **Open**.

---

## First-time setup in Xcode

1. In the Project Navigator, click the blue **SpatialRehab** project icon.
2. Select the **SpatialRehab** target.
3. Open **Signing & Capabilities**.
4. Check **Automatically manage signing**.
5. Under **Team**, pick your personal team / Apple ID.
   - If the list is empty: **Xcode → Settings → Accounts → +** and add your Apple ID.
6. **Change the bundle identifier to your own** for device builds, e.g. `com.yourname.SpatialRehab`.

> ⚠️ **Do not all share `com.spatialrehab.SpatialRehab` when deploying to the headset.** Multiple people signing the same bundle ID with different personal teams will fight over provisioning profiles. Keep the shared ID only for Simulator builds.

No SPM packages are required. ARKit usage strings are already in `SpatialRehab/Info.plist` (not separate Xcode capabilities).

---

## How to run on device — primary for ARKit

Use a real headset when verifying hand tracking, world sensing, passthrough comfort, or demo capture.

1. **On the headset:** Settings → **Privacy & Security** → **Developer Mode** → On. The device restarts.
2. Put the headset and the Mac on the **same Wi-Fi network**.
3. In Xcode: **Window → Devices and Simulators** → pair the Apple Vision Pro. Enter the code shown in the headset.
4. Select the paired **Apple Vision Pro** as the run destination and press **Play** (`Cmd + R`).
5. **First run only:** on the headset, Settings → **General** → **VPN & Device Management** → trust your developer certificate.

**Notes**

- A free Apple ID works. The provisioning profile expires after **7 days** — re-run from Xcode to refresh it.
- Deployment over Wi-Fi is slower than the Simulator. Expect 30–60 s per run.
- Battery life is roughly **2 hours**. Keep it charging while you develop.
- If the device does not appear: confirm Developer Mode is on, the headset has restarted, and both machines are on the same subnet (not a guest network).

**What must be tested on device (not representative on Simulator):**

- Hand tracking / proximity used by the Making Tea immersive prototype (`HandProximityTracker`, `ImmersiveTaskView`)
- World sensing / tabletop anchoring for AR guidance markers
- Passthrough composition, panel placement, and comfort
- Anything you plan to screen-record for the demo

---

## How to run on the Simulator — UI and most product flows

Most of the shipped patient flow runs in Simulator: baseline battery, home screen, Daily Practice, Caregiver Dashboard, Who am I?, and Remember the Way (table + step-inside are code-built meshes / MapKit — not device-only).

1. Open the run destination menu next to the **SpatialRehab** scheme.
2. Choose a **visionOS Simulator** (e.g. Apple Vision Pro).
3. Press **Play** (▶) / `Cmd + R`.

If you have no visionOS runtime: **Xcode → Settings → Components** (called **Platforms** in Xcode 15 and earlier) and install **visionOS 26.2**.

### If you only see iPhone / iPad destinations

- Confirm your Xcode ships the visionOS 26.2 SDK.
- Confirm the scheme is **SpatialRehab**.
- Install the visionOS platform in Xcode Settings if missing.

### What you should see after launch

1. **Baseline assessment** (currently every launch while under development — see `SpatialRehabApp.hasCompletedBaseline`; not yet persisted as one-time only).
2. After finishing or exiting the battery → **home screen** (`ContentView`):
   - **Start** — Remember the Way (opens the shared `ActivitySpace` immersive space)
   - **Daily Practice** — leveled mini-games hub
   - **Caregiver Dashboard** — trend charts (sheet)
   - **Who am I?** — name card / family tree windows

---

## Current project configuration

| Setting | Value |
|---------|--------|
| **Product name** | SpatialRehab |
| **Platform** | visionOS only |
| **SDK** | visionOS **26.2** |
| **Minimum deployment** | visionOS **26.2** |
| **Language / UI** | Swift + SwiftUI, RealityKit, MapKit, Swift Charts; ARKit for hand / world sensing |
| **Entry point** | `SpatialRehab/SpatialRehabApp.swift` |
| **Main window** | Baseline first (`BaselineAssessmentView`), then `ContentView` |
| **Immersive spaces** | `ActivitySpace` (Remember the Way), `TeaTaskSpace` (Making Tea prototype — scene still declared, not linked from the home UI) |
| **Bundle ID** | `com.spatialrehab.SpatialRehab` (override per-developer for device builds) |
| **Version** | Marketing `1.0` / Build `1` |
| **Scheme** | `SpatialRehab` (shared) |
| **Signing** | Automatic; **Development Team left empty** — each person sets their own |
| **Dependencies** | None (no SPM packages) |

### Product surfaces on `main`

| Surface | Primary paths | Role |
|---------|----------------|------|
| **Baseline battery** | `Views/*GameView.swift`, `Models/BaselineAssessment*.swift` | 8-game first-run cognitive assessment, silently scored |
| **Remember the Way** | `RouteMemoryView.swift`, `RouteMemoryExercise.swift`, `NeighborhoodWorld.swift`, `TiongBahruMap.json` | Study → recall → step-inside wayfinding |
| **Daily Practice** | `Views/DailyPracticeHubView.swift`, `Models/Practice*.swift` | Repeatable leveled mini-games |
| **Caregiver dashboard** | `Views/CaregiverDashboardView.swift`, `Views/ScoreTrendChart.swift`, `Models/BaselineResultsStore.swift` | Per-game trends + clock-drawing gallery |
| **Recommendation engine** | `Models/GameRecommendationEngine.swift` | Ranks weakest domain (wired into dev debug view) |
| **Who am I?** | `WhoAmI/*` | Name card + family tree (separate windows) |
| **Making Tea (prototype)** | `Views/ImmersiveTaskView.swift`, `Models/TaskSession.swift`, `TeaTaskContent.swift` | AR guided task; immersive scene kept, not on home nav |
| **My People** | `Views/MyPeopleView.swift` | Reminiscence cards; not yet wired into navigation |

Design notes: `Docs/BaselineAssessment_Design.md`, `Docs/DailyPractice_Design.md`, `Docs/TaskDesign_MakingTea.md`.

### Required Info.plist keys

These live in `SpatialRehab/Info.plist`. ARKit authorization can fail silently without them:

| Key | Why |
|-----|-----|
| `NSHandsTrackingUsageDescription` | Hand reach / proximity for guided steps (`HandProximityTracker`) |
| `NSWorldSensingUsageDescription` | Tabletop / world anchors for AR guidance markers |

### Repo layout

```text
SpatialRehab/                         ← repo root
├── Xcode_README.md                   ← this file (Xcode setup)
├── README.md                         ← product overview
├── AGENTS.md / CLAUDE.md             ← agent guide
├── CHANGELOG.md                      ← record all file writes here
├── Docs/                             ← design docs
├── assets/                           ← logo, screenshots for README
├── SpatialRehab.xcodeproj/           ← OPEN THIS in Xcode
├── project.yml                       ← XcodeGen definition
└── SpatialRehab/                     ← app source
    ├── SpatialRehabApp.swift         ← scenes: main window, ActivitySpace, TeaTask, Who am I?
    ├── ContentView.swift             ← home after baseline
    ├── AppModel.swift                ← Remember the Way session state
    ├── RouteMemoryExercise.swift
    ├── RouteMemoryView.swift         ← holographic table + step-inside
    ├── NeighborhoodWorld.swift       ← procedural Tiong Bahru mesh
    ├── TiongBahruMap.json            ← OSM extract for the neighborhood
    ├── VoiceGuide.swift
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/                       ← baseline, practice, tea task, recommendations
    ├── Views/                        ← games, dashboard, daily practice, immersive tea
    ├── WhoAmI/                       ← name card / family tree
    └── *.usdz                        ← 3D prop library (many assets; not all wired)
```

---

## Adding new source files (read this)

The project is generated by **XcodeGen** from `project.yml`. The checked-in `.xcodeproj` is what most people open, but **`project.yml` is the source of truth**.

```bash
brew install xcodegen   # once
xcodegen generate
```

> ⚠️ **Do not add files through the Xcode UI.** Put new `.swift` files under `SpatialRehab/`, then run `xcodegen generate` and re-open the project. Files added only in Xcode are lost the next time anyone regenerates.

Anyone who edits `project.yml` must regenerate and commit the resulting `.xcodeproj`.

---

## Common problems

| Problem | What to try |
|---------|-------------|
| **New file not compiling / not in project** | Run `xcodegen generate` and re-open |
| **"No such module" / cannot build** | Confirm visionOS 26.2 SDK; **Product → Clean Build Folder** (`Cmd + Shift + K`) |
| **API unavailable / wrong signature** | Confirm deployment target is **visionOS 26.2** |
| **Signing errors** | Set your **Team**; use your own bundle ID for device builds |
| **Headset not listed in Xcode** | Developer Mode on → restart headset → same Wi-Fi (not guest) → re-pair in Devices and Simulators |
| **"Untrusted Developer" on launch** | Headset → Settings → General → VPN & Device Management → trust the certificate |
| **App installs but relaunches fail after a week** | Free-account profile expired (7 days). Re-run from Xcode |
| **Hand tracking returns nothing** | Expected on Simulator — use device for tea-task / proximity work |
| **Baseline every launch** | Intentional while the battery is under development (`hasCompletedBaseline` is in-memory only). Switch to `@AppStorage` when it should be first-launch-only |
| **Simulator missing** | Xcode Settings → Components (Platforms in Xcode 15 and earlier) → install visionOS 26.2 |
| **Command Line Tools only** | Point `xcode-select` at the full Xcode, not CLT alone |

---

## Screen recording for the demo

Standard visionOS screen recording **does not include passthrough** (privacy). To capture the real room behind the UI, use **Xcode → Developer Capture** with the device connected.

Test this at least once *before* demo day — discovering your footage is a black background on the morning of is not recoverable.

---

## What this is *not* (yet)

- Clinically validated assessment content (word lists / timings are placeholders pending clinical review)
- Accounts, backend, or App Store distribution
- Mac remote-control / multi-Mac networking (intentionally out of scope)
- Fully wired Making Tea + My People entry points on the home screen (code is in-tree)

**Hackathon focus:** a coherent patient path on Apple Vision Pro — baseline → Remember the Way — with caregiver trends and daily practice, Simulator for iteration, device for AR and demo capture.

For product narrative, screenshots, and design principles, see [`README.md`](README.md).
