import RealityKit
import UIKit

/// The floating 3D guidance for the kopi table: a halo under the thing to pick
/// up, a bobbing arrow above it, a travelling arc of dots from it to the mug,
/// and a ring over the mug once she is carrying something.
///
/// Two colours carry two meanings and nothing else: **amber is the thing to
/// pick up**, **cyan is where it goes**. Keeping that mapping strict is what
/// lets the indicators be read at a glance rather than decoded.
///
/// Everything is built once and then only ever moved, scaled, or faded. Per-frame
/// work is transform-only — no meshes or materials are allocated during a step —
/// because this is driven from the activity's 30 Hz tick alongside the pour
/// simulation, and that budget is already spoken for.
@MainActor
final class CoffeeGuidanceIndicators {
    /// Which cues should currently be showing. The activity recomputes this every
    /// tick from the guidance level's schedule; the fades make the changes gentle
    /// enough that it can flip freely without anything snapping.
    struct Cues: Equatable {
        var halo = false
        var arrow = false
        var path = false
        var mugTarget = false

        static let none = Cues()
    }

    private static let amber = UIColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
    private static let cyan = UIColor(red: 0.45, green: 0.87, blue: 0.95, alpha: 1)

    private static let haloDotCount = 24
    private static let pathDotCount = 14
    private static let mugDotCount = 16

    private let root = Entity()
    private let haloGroup = Entity()
    private let beaconGroup = Entity()
    private let pathGroup = Entity()
    private let mugGroup = Entity()

    private var haloDots: [Entity] = []
    private var pathDots: [Entity] = []
    private var mugDots: [Entity] = []

    /// Current rendered opacity per group, eased toward the requested state so a
    /// cue never pops in or out.
    private var opacities: [ObjectIdentifier: Float] = [:]

    /// The animation clock. Deliberately kept here rather than in the view's
    /// `@State`: this advances 30 times a second, and anything in `@State` would
    /// invalidate the SwiftUI body at the same rate.
    private var tick = 0

    private var built = false

    // MARK: - Building

    func attach(to parent: Entity) {
        guard !built else { return }
        built = true

        buildHalo()
        buildBeacon()
        buildPath()
        buildMugTarget()

        for group in [haloGroup, beaconGroup, pathGroup, mugGroup] {
            group.isEnabled = false
            group.components.set(OpacityComponent(opacity: 0))
            opacities[ObjectIdentifier(group)] = 0
            root.addChild(group)
        }
        parent.addChild(root)
    }

    private static func dot(radius: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [UnlitMaterial(color: color)])
    }

    /// A ring of dots that sits flat on the table under the item.
    private func buildHalo() {
        for index in 0..<Self.haloDotCount {
            let angle = Float(index) / Float(Self.haloDotCount) * 2 * .pi
            let dot = Self.dot(radius: 0.0075, color: Self.amber)
            dot.position = [cos(angle) * 0.13, 0, sin(angle) * 0.13]
            haloGroup.addChild(dot)
            haloDots.append(dot)
        }
    }

    /// A downward arrow: a stem with a cone on the bottom, hanging over the item.
    /// The cone's apex points up by default, so it gets flipped.
    private func buildBeacon() {
        let head = ModelEntity(
            mesh: .generateCone(height: 0.05, radius: 0.028),
            materials: [UnlitMaterial(color: Self.amber)]
        )
        head.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        head.position = [0, 0.025, 0]
        beaconGroup.addChild(head)

        let stem = ModelEntity(
            mesh: .generateCylinder(height: 0.05, radius: 0.008),
            materials: [UnlitMaterial(color: Self.amber)]
        )
        stem.position = [0, 0.075, 0]
        beaconGroup.addChild(stem)
    }

    /// Dots laid along the arc from the item to the mug. A brightness wave runs
    /// along them so the arc reads as a direction of travel rather than a fence.
    private func buildPath() {
        for _ in 0..<Self.pathDotCount {
            let dot = Self.dot(radius: 0.0085, color: Self.amber)
            pathGroup.addChild(dot)
            pathDots.append(dot)
        }
    }

    /// The "it goes in here" ring, hovering just over the mug's rim.
    private func buildMugTarget() {
        for index in 0..<Self.mugDotCount {
            let angle = Float(index) / Float(Self.mugDotCount) * 2 * .pi
            let dot = Self.dot(radius: 0.0065, color: Self.cyan)
            dot.position = [cos(angle) * 0.055, 0, sin(angle) * 0.055]
            mugGroup.addChild(dot)
            mugDots.append(dot)
        }
    }

    // MARK: - Per-frame update

    /// - Parameters:
    ///   - target: where the item for this step is standing, or nil when there is
    ///     nothing to point at (between steps, or once the kopi is finished).
    ///   - targetHeight: the item's own height, so the arrow floats above it
    ///     rather than through it.
    func update(
        target: SIMD3<Float>?,
        targetHeight: Float,
        mug: SIMD3<Float>,
        tableY: Float,
        cues: Cues
    ) {
        tick += 1
        let time = Float(tick) / 30
        let wanted = target == nil ? Cues.none : cues

        fade(haloGroup, to: wanted.halo)
        fade(beaconGroup, to: wanted.arrow)
        fade(pathGroup, to: wanted.path)
        fade(mugGroup, to: wanted.mugTarget)

        if let target {
            layoutHalo(at: target, tableY: tableY, time: time)
            layoutBeacon(at: target, targetHeight: targetHeight, time: time)
            layoutPath(from: target, targetHeight: targetHeight, to: mug, time: time)
        }
        layoutMugTarget(at: mug, time: time)
    }

    func hideAll() {
        for group in [haloGroup, beaconGroup, pathGroup, mugGroup] {
            fade(group, to: false)
        }
    }

    private func layoutHalo(at target: SIMD3<Float>, tableY: Float, time: Float) {
        haloGroup.position = [target.x, tableY + 0.004, target.z]
        // The ring breathes outward as a whole, and a slow wave runs round it.
        let breathe = 1 + 0.06 * sin(time * 2.2)
        haloGroup.scale = SIMD3(repeating: breathe)
        for (index, dot) in haloDots.enumerated() {
            let phase = time * 2 - Float(index) / Float(Self.haloDotCount) * 2 * .pi
            dot.scale = SIMD3(repeating: 0.75 + 0.45 * (0.5 + 0.5 * sin(phase)))
        }
    }

    private func layoutBeacon(at target: SIMD3<Float>, targetHeight: Float, time: Float) {
        let bob = 0.018 * sin(time * 2.6)
        beaconGroup.position = [target.x, target.y + targetHeight + 0.11 + bob, target.z]
        beaconGroup.orientation = simd_quatf(angle: time * 0.7, axis: [0, 1, 0])
    }

    private func layoutPath(
        from target: SIMD3<Float>,
        targetHeight: Float,
        to mug: SIMD3<Float>,
        time: Float
    ) {
        let start = SIMD3(target.x, target.y + targetHeight * 0.75, target.z)
        let end = SIMD3(mug.x, mug.y + 0.14, mug.z)
        let span = simd_length(SIMD2(end.x - start.x, end.z - start.z))
        let lift = max(0.09, span * 0.42)

        for (index, dot) in pathDots.enumerated() {
            let t = Float(index) / Float(Self.pathDotCount - 1)
            var point = start + (end - start) * t
            point.y += sin(t * .pi) * lift
            dot.position = point
            // A pulse travels start-to-end roughly every second and a half.
            let head = (time * 0.7).truncatingRemainder(dividingBy: 1)
            var distance = abs(t - head)
            distance = min(distance, 1 - distance)
            dot.scale = SIMD3(repeating: 0.55 + 1.15 * max(0, 1 - distance * 5))
        }
    }

    private func layoutMugTarget(at mug: SIMD3<Float>, time: Float) {
        mugGroup.position = [mug.x, mug.y + 0.15 + 0.01 * sin(time * 2.4), mug.z]
        let breathe = 1 + 0.09 * sin(time * 3.1)
        mugGroup.scale = SIMD3(repeating: breathe)
    }

    /// Eases a group's opacity toward on or off, and disables it once it is fully
    /// invisible so hidden cues cost nothing to draw.
    private func fade(_ group: Entity, to visible: Bool) {
        let key = ObjectIdentifier(group)
        let goal: Float = visible ? 1 : 0
        var current = opacities[key] ?? 0
        guard abs(current - goal) > 0.001 else { return }

        current += (goal - current) * 0.16
        if abs(current - goal) < 0.01 { current = goal }
        opacities[key] = current

        group.isEnabled = current > 0.001
        group.components.set(OpacityComponent(opacity: current))
    }
}
