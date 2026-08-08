import ARKit
import simd

/// Watches the person's hands via ARKit hand tracking and reports how close the tracked
/// index fingertips are to a world-space target point.
///
/// This is what makes the app actually "know what the user is doing," as opposed to the
/// gaze+pinch selection visionOS already gives every SwiftUI/RealityKit control for free
/// (that part needed no extra code — see `ContentView`/`GuidanceCardView` buttons). This
/// tracker is deliberately narrow — distance-to-target only, no gesture classification —
/// because a dementia-friendly design should tolerate an imprecise, slow, or trembling
/// reach rather than require a specific hand shape.
///
/// Known gaps (see `Docs/TaskDesign_MakingTea.md`):
/// - visionOS Simulator's hand-pose simulation is synthetic/limited; treat any simulator
///   result as a smoke test only — real validation needs a device.
/// - No gesture disambiguation: a hand resting near the target also counts, which is the
///   intended trade-off here but is worth knowing about.
/// - `HandTrackingProvider.isSupported` gates this off entirely on unsupported
///   configurations; the app must keep working via the manual "Done" button either way, so
///   this class fails silently (`isAvailable` stays false) rather than erroring the task.
@MainActor
final class HandProximityTracker: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var nearestHandDistance: Float?

    /// World-space point to measure distance against. The owning view updates this each
    /// time the active step's marker changes or moves.
    var targetWorldPosition: SIMD3<Float>? {
        didSet { recomputeNearestDistance() }
    }

    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private var trackingTask: Task<Void, Never>?
    private var leftHandPosition: SIMD3<Float>?
    private var rightHandPosition: SIMD3<Float>?

    func start() {
        guard HandTrackingProvider.isSupported else { return }
        stop()
        trackingTask = Task { [weak self] in
            guard let self else { return }
            let authorization = await session.requestAuthorization(for: [.handTracking])
            guard authorization[.handTracking] == .allowed else { return }
            do {
                try await session.run([provider])
            } catch {
                return
            }
            isAvailable = true
            for await update in provider.anchorUpdates {
                guard !Task.isCancelled else { break }
                apply(update)
            }
        }
    }

    func stop() {
        trackingTask?.cancel()
        trackingTask = nil
        session.stop()
        isAvailable = false
        leftHandPosition = nil
        rightHandPosition = nil
        nearestHandDistance = nil
    }

    private func apply(_ update: AnchorUpdate<HandAnchor>) {
        let hand = update.anchor
        let position: SIMD3<Float>?

        switch update.event {
        case .removed:
            position = nil
        case .added, .updated:
            position = fingertipWorldPosition(for: hand)
        @unknown default:
            position = nil
        }

        switch hand.chirality {
        case .left:
            leftHandPosition = position
        case .right:
            rightHandPosition = position
        @unknown default:
            break
        }

        recomputeNearestDistance()
    }

    private func fingertipWorldPosition(for hand: HandAnchor) -> SIMD3<Float>? {
        guard hand.isTracked, let skeleton = hand.handSkeleton else { return nil }
        let tip = skeleton.joint(.indexFingerTip)
        let worldTransform = hand.originFromAnchorTransform * tip.anchorFromJointTransform
        return SIMD3<Float>(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
    }

    private func recomputeNearestDistance() {
        guard let target = targetWorldPosition else {
            nearestHandDistance = nil
            return
        }
        let distances = [leftHandPosition, rightHandPosition]
            .compactMap { $0 }
            .map { simd_distance($0, target) }
        nearestHandDistance = distances.min()
    }
}
