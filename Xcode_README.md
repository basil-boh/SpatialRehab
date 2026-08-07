# SpatialRehab — Xcode / visionOS setup

This repo is a **minimal visionOS app scaffold**. There is almost no product code yet — just enough structure so the team can open, build, and run the project in **Xcode Beta**.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **Mac** | Required (Xcode only runs on macOS) |
| **Xcode Beta** | This project targets visionOS. Use the beta that ships the visionOS SDK (e.g. **Xcode 27 Beta** / visionOS 27 SDK, or whatever Apple currently ships for visionOS development) |
| **Apple ID** | Free Apple ID is enough to run on the **visionOS Simulator**. A paid developer account is only needed later for a real Apple Vision Pro device |

Install Xcode Beta from [Apple Developer Downloads](https://developer.apple.com/download/applications/) if you do not have it.

After install, open **Xcode Beta once**, accept the license, and let it install additional components if prompted.

---

## How to open the project

### Option A — Finder (easiest)

1. Clone or download this repo.
2. Open the folder in Finder.
3. Double-click **`SpatialRehab.xcodeproj`**  
   (not the `SpatialRehab` folder next to it — open the file that ends in `.xcodeproj`).
4. If macOS asks which app to use, choose **Xcode-beta** (or **Xcode** if that is your beta install name).

### Option B — Terminal

From the repo root:

```bash
open -a Xcode-beta SpatialRehab.xcodeproj
```

If `Xcode-beta` is not found, try:

```bash
open SpatialRehab.xcodeproj
```

…and pick Xcode Beta from the app list if prompted.

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
6. Leave the bundle identifier as-is unless it conflicts on your machine  
   (`com.spatialrehab.SpatialRehab`). If Xcode complains it is already taken, change it to something unique (e.g. `com.yourname.SpatialRehab`).

You do **not** need to change deployment target, capabilities, or build settings for the scaffold to run on the simulator.

---

## How to run (visionOS Simulator)

1. At the top of the Xcode window, open the run destination menu (next to the scheme name **SpatialRehab**).
2. Choose a **visionOS Simulator** (e.g. **Apple Vision Pro**).
3. Press the **Play** button (▶), or **Product → Run**, or `Cmd + R`.
4. Wait for the simulator to boot. You should see a simple window with the text **SpatialRehab**.

That is the entire app for now — intentionally empty beyond the scaffold.

### If you only see iPhone / iPad destinations

- Confirm you opened **Xcode Beta** (stable Xcode may not include the visionOS SDK).
- Confirm the scheme is **SpatialRehab** (top toolbar).
- **Xcode → Settings → Platforms** (or **Components** on older betas) and install **visionOS** if it is listed but missing.

---

## Current project configuration

| Setting | Value |
|---------|--------|
| **Product name** | SpatialRehab |
| **Platform** | visionOS only (not iOS / macOS) |
| **Minimum deployment** | visionOS **2.0** |
| **Language / UI** | Swift + SwiftUI |
| **Entry point** | `SpatialRehab/SpatialRehabApp.swift` |
| **Main UI** | `SpatialRehab/ContentView.swift` (placeholder text only) |
| **Bundle ID** | `com.spatialrehab.SpatialRehab` |
| **Version** | Marketing `1.0` / Build `1` |
| **Scheme** | `SpatialRehab` (shared, checked into git) |
| **Signing** | Automatic; **Development Team left empty** — each person sets their own Team |
| **Capabilities** | None added yet |
| **Dependencies** | None (no SPM packages, CocoaPods, etc.) |
| **App icon** | Placeholder asset slots only (no real artwork yet) |

### Repo layout (what matters)

```text
SpatialRehab/                      ← repo root
├── Xcode_README.md                ← this file
├── SpatialRehab.xcodeproj/        ← OPEN THIS in Xcode
├── project.yml                    ← XcodeGen definition (optional to regenerate)
├── .gitignore
└── SpatialRehab/                  ← app source
    ├── SpatialRehabApp.swift
    ├── ContentView.swift
    ├── Info.plist
    └── Assets.xcassets/
```

---

## Optional: regenerate the Xcode project

Most teammates **do not need this**. The `.xcodeproj` is already in the repo.

If someone edits `project.yml` and you need to rebuild the project file:

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From the repo root:

```bash
xcodegen generate
```

Then re-open `SpatialRehab.xcodeproj`.

---

## Common problems

| Problem | What to try |
|---------|-------------|
| **“No such module” / cannot build** | Use Xcode Beta with the visionOS SDK; clean with **Product → Clean Build Folder** (`Cmd + Shift + K`), then run again |
| **Signing errors** | Set your **Team** under Signing & Capabilities; use a unique bundle ID if needed |
| **Wrong Xcode opens** | Right-click `.xcodeproj` → **Open With → Xcode-beta**, or use `open -a Xcode-beta SpatialRehab.xcodeproj` |
| **Simulator missing** | Install the visionOS platform/runtime from Xcode Settings → Platforms |
| **Command Line Tools only** | Installing CLT is not enough — you need the full **Xcode Beta** app |

---

## What this is *not* (yet)

- No immersive spaces / RealityKit scenes
- No networking, accounts, or backend
- No tests target
- No App Store / distribution setup

When the team is ready to build features, start from `ContentView.swift` / `SpatialRehabApp.swift` and add targets or packages as needed.
