# SpatialRehab — Xcode / visionOS setup

This repo is a **minimal visionOS app scaffold** for a hackathon / product sprint: help people with dementia relearn **daily tasks** (home, medication, routines) in spatial computing.

There is almost no product code yet — just enough structure so the team can open, build, and run in **Xcode Beta** on the **visionOS Simulator**.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **Mac** | Required (Xcode only runs on macOS) |
| **Xcode Beta** | Use the beta that ships the visionOS SDK (e.g. **Xcode 27 Beta** / visionOS 27 SDK) |
| **Apple ID** | Free Apple ID is enough to run on the **visionOS Simulator**. A paid developer account is only needed later for a real Apple Vision Pro |

Install Xcode Beta from [Apple Developer Downloads](https://developer.apple.com/download/applications/) if you do not have it.

After install, open **Xcode Beta once**, accept the license, and let it install additional components if prompted.

**CLI tip:** if `xcodebuild` only finds Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

Or:

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
4. If macOS asks which app to use, choose **Xcode-beta**.

### Option B — Terminal

```bash
open -a Xcode-beta SpatialRehab.xcodeproj
```

### Option C — From inside Xcode

1. Launch **Xcode Beta**.
2. **File → Open…**
3. Select `SpatialRehab.xcodeproj` inside this repo.
4. Click **Open**.

---

## First-time setup in Xcode

1. In the left sidebar (Project Navigator), click the blue **SpatialRehab** project icon at the top.
2. Select the **SpatialRehab** target.
3. Open the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Under **Team**, pick your personal team / Apple ID.  
   - If the list is empty: **Xcode → Settings → Accounts → +** and add your Apple ID.
6. Leave the bundle identifier as-is unless it conflicts  
   (`com.spatialrehab.SpatialRehab`). If taken, change it (e.g. `com.yourname.SpatialRehab`).

You do **not** need extra capabilities or packages for the scaffold to run on the simulator.

---

## How to run (visionOS Simulator)

1. At the top of the Xcode window, open the run destination menu (next to the scheme **SpatialRehab**).
2. Choose a **visionOS Simulator** (e.g. **Apple Vision Pro**).
3. Press **Play** (▶), or **Product → Run**, or `Cmd + R`.
4. Wait for the simulator to boot. You should see a welcome window: **SpatialRehab**.
5. From the welcome screen:
   - **Walk in VR (first person)** — immersive path; **left hand pinch** to walk (hold = continuous), **right hand pinch** to turn L/R; green **You have arrived** at Block 343. Hand tracking needs a real Vision Pro; Simulator uses Step/Left/Right buttons.
   - **Yishun Map Route** — MapKit overview (polyline, Look Around, traffic-light coaching). Toolbar **Signal preview** for volumetric light.
   - **Hummingbird** — existing volumetric USDZ demo.

Network access is required for `MKDirections` and Look Around imagery.

If you have no visionOS runtime: **Xcode → Settings → Platforms** and install **visionOS**.

### If you only see iPhone / iPad destinations

- Confirm you opened **Xcode Beta** (stable Xcode may not include the visionOS SDK).
- Confirm the scheme is **SpatialRehab**.
- **Xcode → Settings → Platforms** and install **visionOS** if missing.

---

## Current project configuration

| Setting | Value |
|---------|--------|
| **Product name** | SpatialRehab |
| **Platform** | visionOS only |
| **Minimum deployment** | visionOS **26.0** (raised from 2.0 for the `.manipulable()` hand-interaction API) |
| **Language / UI** | Swift + SwiftUI |
| **Entry point** | `SpatialRehab/SpatialRehabApp.swift` |
| **Main UI** | `SpatialRehab/ContentView.swift` (welcome screen) |
| **Bundle ID** | `com.spatialrehab.SpatialRehab` |
| **Version** | Marketing `1.0` / Build `1` |
| **Scheme** | `SpatialRehab` (shared) |
| **Signing** | Automatic; **Development Team left empty** — each person sets their own Team |
| **Capabilities** | None |
| **Dependencies** | None (no SPM packages) |

### Repo layout (what matters)

```text
SpatialRehab/                      ← repo root
├── Xcode_README.md                ← this file
├── SpatialRehab.xcodeproj/        ← OPEN THIS in Xcode
├── project.yml                    ← XcodeGen definition (optional to regenerate)
└── SpatialRehab/                  ← app source
    ├── SpatialRehabApp.swift
    ├── ContentView.swift
    ├── HummingbirdVolumeView.swift
    ├── YishunWalk/                ← MapKit walking demo (Yishun route)
    ├── Info.plist
    └── Assets.xcassets/
```

After adding Swift files under `SpatialRehab/`, regenerate the Xcode project if needed:

```bash
xcodegen generate
```

---

## Optional: regenerate the Xcode project

Most teammates **do not need this**. The `.xcodeproj` is already in the repo.

If someone edits `project.yml`:

```bash
brew install xcodegen   # once
xcodegen generate
```

Then re-open `SpatialRehab.xcodeproj`.

---

## Common problems

| Problem | What to try |
|---------|-------------|
| **“No such module” / cannot build** | Use Xcode Beta with the visionOS SDK; clean with **Product → Clean Build Folder** (`Cmd + Shift + K`) |
| **Signing errors** | Set your **Team** under Signing & Capabilities; unique bundle ID if needed |
| **Wrong Xcode opens** | Right-click `.xcodeproj` → **Open With → Xcode-beta** |
| **Simulator missing** | Xcode Settings → Platforms → install visionOS |
| **Command Line Tools only** | Point tools at full **Xcode Beta**, not CLT alone |

---

## What this is *not* (yet)

- Full rehab exercises / RealityKit rooms
- Mac remote-control / multi-Mac networking (intentionally out of scope for the hackathon)
- Accounts, backend, or App Store distribution

**Hackathon focus:** build one daily-task experience on visionOS that judges can see on the simulator (or a headset).
