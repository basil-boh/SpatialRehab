---
name: mahjong-ui-components
description: Spatial layout, tile geometry, seating quadrants, discard rivers, wall assembly, and AI-opponent conventions for an immersive visionOS mahjong table. Use when building or refining the mahjong activity's 3D presentation and turn mechanics.
---

# Spatial Mahjong AI Co-Pilot

(Installed from user-provided content on 2026-08-09; original download link `github.com/Teng-AI/mahjong` was unavailable. The spec below targets Japanese Riichi mahjong — for SpatialRehab, adopt the SPATIAL and PRESENTATION conventions; game rules stay simplified for the dementia audience and the SG148 Singapore set.)

## Role & Mission
You are an elite VisionOS Software Architect, Spatial Interaction Designer, and Riichi Mahjong Grandmaster. The application is built using Swift, SwiftUI, RealityKit, and ARKit. The human user plays in an immersive space against three local, isolated Computer AI Opponents.

## 1. Physical Scale & Spatial Coordinate System

Table center is the origin; tabletop surface at Y = 0.

### A. Tile Geometry (Standard Japanese Dimensions)
- Width (X): 2.6 cm (0.026 m)
- Height (Y): 3.4 cm (0.034 m)
- Thickness (Z): 2.0 cm (0.020 m)

### B. Player Spatial Quadrants & Orientations
1. Player 0 (Human — East): position (0, 0, -0.4), yaw 0° (facing +Z)
2. Player 1 (AI Left — South): position (-0.4, 0, 0), yaw 270°
3. Player 2 (AI Across — West): position (0, 0, 0.4), yaw 180°
4. Player 3 (AI Right — North): position (0.4, 0, 0), yaw 90°

## 2. 3D Game Rules Mapped to Spatial Transformations

### A. The Hidden Hand
- Human hand: 13 tiles aligned along X, pitched -15° toward the seated eye line.
- AI hands stand vertically facing away from the human.
- Anti-cheat: if the user leans past an AI's hand boundary, render those faces blank.

### B. The Discard Rivers (grid logic)
- Each player owns a 3-row × 6-column grid starting 0.12 m from their hand zone toward the origin.
- Discards lie flat, face up, oriented to their owner.
- Riichi declaration: the tile turns 90° sideways; the next tile in that row gets a +0.8 cm offset (3.4 − 2.6) to prevent clipping.

### C. Open Melds
- Sorted to the far right of the owner's hand zone.
- The stolen tile rotates 90° to document its source: leftmost = stolen from left, center = across, rightmost = right.

### D. The Wall & Dead Wall
- Four-sided hollow square, 136 tiles (17 double-stacked columns per side); upper tier at Y = thickness.
- After the dice roll, break the wall with a 1.5 cm gap at the draw point; final 14 tiles are the immutable Dead Wall.

## 3. Computer AI Opponent Engine
- AI threads see only: their own hand, all public discard rivers, and open melds.
- Turn pipeline: Tsumo check → uke-ire efficiency discard → defensive genbutsu play when anyone declares Riichi.
- Humanized delay 0.6–1.5 s per decision, with a +5 mm hover micro-animation on the tile being considered.
- Steal window: pause 0.8 s after every discard; resolve Pon/Chii/Kan priority with a spatial audio cue at the caller's seat.

## 4. Architecture
Decouple rendering, game logic, and AI computation so shanten/AI math never stutters the RealityKit layer.
