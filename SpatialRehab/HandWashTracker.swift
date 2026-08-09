import ARKit
import Observation
import simd

/// Follows the patient's real hands during the mahjong wash so the tiles
/// can drift away from wherever their palms actually are — the wash phase
/// reads these positions every frame and pushes nearby tiles aside.
@Observable
@MainActor
final class HandWashTracker {
    /// World-space palm positions (0–2 entries), refreshed continuously while
    /// tracking runs. Stays empty on the simulator, when hand tracking is
    /// unsupported or denied, or when no hands are currently seen.
    private(set) var palms: [SIMD3<Float>] = []

    private let session = ARKitSession()
    private var updateTask: Task<Void, Never>?
    private var leftPalm: SIMD3<Float>?
    private var rightPalm: SIMD3<Float>?

    /// Asks for hand-tracking permission if needed, then starts streaming
    /// palm positions. Silently does nothing when the device can't track
    /// hands (like the simulator) or the patient declined permission.
    func start() async {
        guard HandTrackingProvider.isSupported else { return }
        guard updateTask == nil else { return }

        let authorizations = HandTrackingProvider.requiredAuthorizations
        let results = await session.requestAuthorization(for: authorizations)
        guard authorizations.allSatisfy({ results[$0] == .allowed }) else { return }

        // Providers can't be re-run after a stop, so build a fresh one each start.
        let provider = HandTrackingProvider()
        do {
            try await session.run([provider])
        } catch {
            return
        }

        updateTask = Task { [weak self] in
            for await update in provider.anchorUpdates {
                guard let self else { return }
                self.apply(update)
            }
        }
    }

    /// Stops tracking and forgets the last known palm positions.
    func stop() {
        updateTask?.cancel()
        updateTask = nil
        session.stop()
        leftPalm = nil
        rightPalm = nil
        palms = []
    }

    private func apply(_ update: AnchorUpdate<HandAnchor>) {
        let anchor = update.anchor
        let isVisible = update.event != .removed && anchor.isTracked
        let position = isVisible ? palmPosition(of: anchor) : nil
        if anchor.chirality == .left {
            leftPalm = position
        } else {
            rightPalm = position
        }
        palms = [leftPalm, rightPalm].compactMap { $0 }
    }

    /// A hand anchor's origin sits at the wrist, so when the skeleton is
    /// available we offset to the middle-finger metacarpal joint instead —
    /// it lands much closer to the true centre of the palm.
    private func palmPosition(of anchor: HandAnchor) -> SIMD3<Float> {
        let originFromAnchor = anchor.originFromAnchorTransform
        guard let skeleton = anchor.handSkeleton else {
            return originFromAnchor.translation
        }
        let joint = skeleton.joint(.middleFingerMetacarpal)
        guard joint.isTracked else {
            return originFromAnchor.translation
        }
        return (originFromAnchor * joint.anchorFromJointTransform).translation
    }
}

private extension simd_float4x4 {
    /// The position part of a rigid transform.
    var translation: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
}
