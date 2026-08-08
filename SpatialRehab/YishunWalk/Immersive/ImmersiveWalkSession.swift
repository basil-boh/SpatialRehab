import Foundation
import Observation
import simd

/// First-person VR walk: free movement on XZ with yaw; left pinch walks, right pinch turns.
@MainActor
@Observable
final class ImmersiveWalkSession {
    enum Phase: Equatable {
        case closed
        case opening
        case open
        case failed
    }

    /// Immersive space lifecycle for UI controls.
    var phase: Phase = .closed

    /// Player position in world meters (path destination is at +Z).
    var position: SIMD3<Float> = .zero

    /// Facing yaw in radians. 0 = looking toward +Z (down the road).
    var yawRadians: Float = 0

    /// Total path length in meters (virtual scale).
    let pathLength: Float = 36

    /// True once the user is within the arrival radius of the destination.
    var hasArrived = false

    /// Celebration UI one-shot.
    var showArrivalBanner = false

    /// Status line for HUD (hand tracking).
    var locomotionHint = "Left pinch = walk · Right pinch = turn"

    /// How far one discrete pinch step moves the walker.
    let stepMeters: Float = 1.15

    /// Continuous hold rates (per ~33ms tick from hand tracker).
    let continuousWalkMetersPerTick: Float = 0.085
    let continuousTurnRadiansPerTick: Float = 0.045

    /// Arrival threshold in meters from the destination marker.
    let arrivalRadius: Float = 2.2

    var destination: SIMD3<Float> {
        SIMD3(0, 0, pathLength)
    }

    var distanceToDestination: Float {
        simd_length(SIMD3(position.x - destination.x, 0, position.z - destination.z))
    }

    var progress: Float {
        let traveled = pathLength - distanceToDestination
        return min(1, max(0, traveled / pathLength))
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var remainingMeters: Float {
        max(0, distanceToDestination)
    }

    /// Facing direction on the ground plane.
    var forward: SIMD3<Float> {
        SIMD3(sin(yawRadians), 0, cos(yawRadians))
    }

    func worldOrientation() -> simd_quatf {
        // View of point p: R(-yaw) * (p - position)
        simd_quatf(angle: -yawRadians, axis: SIMD3(0, 1, 0))
    }

    func worldPosition() -> SIMD3<Float> {
        let rot = worldOrientation()
        // Nudge start so first view looks slightly down the road.
        return rot.act(-position) + SIMD3(0, 0, -0.5)
    }

    func resetWalk() {
        position = .zero
        hasArrived = false
        showArrivalBanner = false
        yawRadians = 0
    }

    /// Discrete forward step (left-hand pinch rising edge).
    func walkForward(steps: Float = 1) {
        guard !hasArrived else { return }
        position += forward * (stepMeters * steps)
        evaluateArrival()
    }

    func walkBackward(steps: Float = 1) {
        position -= forward * (stepMeters * steps)
        // Soft clamp: don't go far behind start.
        if position.z < -2 { position.z = -2 }
        if distanceToDestination > arrivalRadius {
            hasArrived = false
            showArrivalBanner = false
        }
    }

    /// Continuous walk along facing direction.
    func applyLocomotion(forwardMeters: Float) {
        guard !hasArrived else { return }
        let clamped = min(max(forwardMeters, -0.25), 0.25)
        position += forward * clamped
        evaluateArrival()
    }

    /// Continuous yaw change (right-hand pinch).
    func applyTurn(radians: Float) {
        guard !hasArrived else { return }
        let clamped = min(max(radians, -0.12), 0.12)
        yawRadians += clamped
        // Keep yaw in a reasonable range for stability.
        if yawRadians > .pi { yawRadians -= 2 * .pi }
        if yawRadians < -.pi { yawRadians += 2 * .pi }
    }

    private func evaluateArrival() {
        if distanceToDestination <= arrivalRadius {
            if !hasArrived {
                hasArrived = true
                showArrivalBanner = true
            }
            // Snap gently near destination so the door is in view.
            let toDest = destination - position
            if simd_length(toDest) > 0.01 {
                position = destination - simd_normalize(SIMD3(toDest.x, 0, toDest.z)) * 1.2
            }
        }
    }

    func dismissArrivalBanner() {
        showArrivalBanner = false
    }
}
