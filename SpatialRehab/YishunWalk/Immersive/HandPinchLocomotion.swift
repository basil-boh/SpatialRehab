import ARKit
import Foundation
import Observation
import simd

/// Reads hand anchors and drives first-person walk/turn from pinches.
///
/// - **Left hand pinch**: walk in facing direction (tap = step, hold = continuous)
/// - **Right hand pinch**: turn left/right from palm X (hold = continuous turn)
@MainActor
@Observable
final class HandPinchLocomotion {
    enum Status: Equatable {
        case idle
        case unsupported
        case denied
        case running
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var leftPinching = false
    private(set) var rightPinching = false
    /// -1…1 while right pinching: negative = turn left, positive = turn right.
    private(set) var turnAxis: Float = 0
    private(set) var isWalkingFromLeftHold = false

    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private var updatesTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    private var leftWasPinching = false
    private var rightWasPinching = false

    /// Distance between thumb tip and index tip (meters) to count as a pinch.
    private let pinchThreshold: Float = 0.025
    private let releaseThreshold: Float = 0.045

    /// Hold longer than this before continuous walk engages (after the first step).
    private let holdContinuousAfter: TimeInterval = 0.28
    private var leftPinchStartedAt: TimeInterval?
    private var didEmitLeftStep = false

    private weak var walkSession: ImmersiveWalkSession?

    func attach(walkSession: ImmersiveWalkSession) {
        self.walkSession = walkSession
    }

    func start() async {
        guard status != .running else { return }

        guard HandTrackingProvider.isSupported else {
            status = .unsupported
            return
        }

        let auth = await session.requestAuthorization(for: HandTrackingProvider.requiredAuthorizations)
        let allowed = auth.values.allSatisfy { $0 == .allowed }
        guard allowed else {
            status = .denied
            return
        }

        do {
            try await session.run([provider])
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        status = .running

        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await update in self.provider.anchorUpdates {
                if Task.isCancelled { break }
                self.handle(anchor: update.anchor)
            }
        }

        tickTask?.cancel()
        tickTask = Task { [weak self] in
            // ~30 Hz locomotion tick while holds are active.
            while let self, !Task.isCancelled {
                self.tickLocomotion()
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        tickTask?.cancel()
        tickTask = nil
        leftPinching = false
        rightPinching = false
        isWalkingFromLeftHold = false
        turnAxis = 0
        leftWasPinching = false
        rightWasPinching = false
        leftPinchStartedAt = nil
        didEmitLeftStep = false
        status = .idle
        // ARKitSession stops when provider is no longer needed; re-run on next start.
    }

    // MARK: - Anchor handling

    private func handle(anchor: HandAnchor) {
        guard anchor.isTracked, let skeleton = anchor.handSkeleton else {
            clearHand(anchor.chirality)
            return
        }

        switch anchor.chirality {
        case .left:
            let pinching = isPinching(anchor: anchor, skeleton: skeleton, wasPinching: leftPinching)
            updateLeft(pinching: pinching)
        case .right:
            let pinching = isPinching(anchor: anchor, skeleton: skeleton, wasPinching: rightPinching)
            updateRight(pinching: pinching, anchor: anchor)
        @unknown default:
            break
        }
    }

    private func clearHand(_ chirality: HandAnchor.Chirality) {
        switch chirality {
        case .left:
            leftPinching = false
            leftWasPinching = false
            leftPinchStartedAt = nil
            didEmitLeftStep = false
            isWalkingFromLeftHold = false
        case .right:
            rightPinching = false
            rightWasPinching = false
            turnAxis = 0
        @unknown default:
            break
        }
    }

    private func updateLeft(pinching: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        leftPinching = pinching

        if pinching && !leftWasPinching {
            // Rising edge → one step immediately.
            leftPinchStartedAt = now
            didEmitLeftStep = true
            isWalkingFromLeftHold = false
            walkSession?.walkForward(steps: 1)
        } else if pinching, let start = leftPinchStartedAt {
            if now - start >= holdContinuousAfter {
                isWalkingFromLeftHold = true
            }
        } else if !pinching {
            leftPinchStartedAt = nil
            didEmitLeftStep = false
            isWalkingFromLeftHold = false
        }

        leftWasPinching = pinching
    }

    private func updateRight(pinching: Bool, anchor: HandAnchor) {
        rightPinching = pinching

        if pinching {
            // Hand position relative to head-ish origin: x < 0 turn left, x > 0 turn right.
            // Wrist/anchor translation.x in world (device-relative enough for direction intent).
            let x = anchor.originFromAnchorTransform.columns.3.x
            // Soft dead zone so resting hand doesn't spin.
            let dead: Float = 0.06
            if abs(x) < dead {
                turnAxis = 0
            } else {
                turnAxis = max(-1, min(1, x * 3.5))
            }
        } else {
            turnAxis = 0
        }

        rightWasPinching = pinching
    }

    private func tickLocomotion() {
        guard let walk = walkSession, !walk.hasArrived else { return }

        // Continuous walk while left pinch held.
        if isWalkingFromLeftHold && leftPinching {
            walk.applyLocomotion(forwardMeters: walk.continuousWalkMetersPerTick)
        }

        // Continuous turn while right pinch held.
        if rightPinching, abs(turnAxis) > 0.05 {
            walk.applyTurn(radians: turnAxis * walk.continuousTurnRadiansPerTick)
        }
    }

    private func isPinching(anchor: HandAnchor, skeleton: HandSkeleton, wasPinching: Bool) -> Bool {
        let thumb = skeleton.joint(.thumbTip)
        let index = skeleton.joint(.indexFingerTip)
        guard thumb.isTracked, index.isTracked else { return false }

        let hand = anchor.originFromAnchorTransform
        let thumbPos = simd_mul(hand, thumb.anchorFromJointTransform).columns.3
        let indexPos = simd_mul(hand, index.anchorFromJointTransform).columns.3
        let t = SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z)
        let i = SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z)
        let distance = simd_length(t - i)

        // Hysteresis: easier to stay pinched once started.
        if wasPinching {
            return distance < releaseThreshold
        }
        return distance < pinchThreshold
    }
}


