import RealityKit
import SwiftUI

/// Full immersive first-person walk driven by hand pinches (with button fallback).
struct ImmersiveWalkSpaceView: View {
    @Environment(ImmersiveWalkSession.self) private var session
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var hands = HandPinchLocomotion()

    var body: some View {
        @Bindable var session = session

        RealityView { content, attachments in
            let world = ImmersivePathWorld.makeWorld(pathLength: session.pathLength)
            // Clear any baked offset; pose is driven every frame from player state.
            world.position = .zero
            content.add(world)
            applyWorldPose(to: world)

            if let hud = attachments.entity(for: "hud") {
                hud.position = [0, 1.25, -1.05]
                content.add(hud)
            }

            if let arrival = attachments.entity(for: "arrival") {
                arrival.position = [0, 1.45, -1.15]
                arrival.isEnabled = false
                content.add(arrival)
            }
        } update: { content, attachments in
            if let world = content.entities.first(where: { $0.name == ImmersivePathWorld.worldRootName }) {
                applyWorldPose(to: world)
            }

            if let arrival = attachments.entity(for: "arrival") {
                arrival.isEnabled = session.showArrivalBanner
                arrival.position = [0, 1.45, -1.15]
            }

            if let hud = attachments.entity(for: "hud") {
                hud.isEnabled = !session.showArrivalBanner
            }
        } attachments: {
            Attachment(id: "hud") {
                walkHUD
            }
            Attachment(id: "arrival") {
                arrivalCard
            }
        }
        .task {
            hands.attach(walkSession: session)
            await hands.start()
            session.locomotionHint = hintForHandsStatus()
        }
        .onChange(of: hands.status) { _, _ in
            session.locomotionHint = hintForHandsStatus()
        }
        .onDisappear {
            hands.stop()
        }
    }

    // MARK: - HUD

    private var walkHUD: some View {
        VStack(spacing: 12) {
            Text("Walk to Block 343")
                .font(.headline)

            ProgressView(value: Double(session.progress))
                .tint(.teal)

            if session.hasArrived {
                Text("Arrived at destination")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("\(session.progressPercent)% · \(Int(session.remainingMeters.rounded())) m left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Live hand state
            HStack(spacing: 16) {
                Label(
                    hands.leftPinching ? (hands.isWalkingFromLeftHold ? "Walking…" : "Step") : "Left pinch",
                    systemImage: hands.leftPinching ? "hand.point.up.left.fill" : "hand.point.up.left"
                )
                .foregroundStyle(hands.leftPinching ? .teal : .secondary)

                Label(
                    hands.rightPinching
                        ? (hands.turnAxis < -0.05 ? "Turning left" : hands.turnAxis > 0.05 ? "Turning right" : "Hold to turn")
                        : "Right pinch",
                    systemImage: hands.rightPinching ? "hand.point.up.left.fill" : "hand.point.up.left"
                )
                .foregroundStyle(hands.rightPinching ? .orange : .secondary)
            }
            .font(.caption.weight(.medium))

            Text(session.locomotionHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Fallback controls (Simulator / denied hands)
            HStack(spacing: 10) {
                Button {
                    session.applyTurn(radians: -0.2)
                } label: {
                    Label("Left", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button {
                    session.walkForward()
                } label: {
                    Label("Step", systemImage: "figure.walk")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(session.hasArrived)

                Button {
                    session.applyTurn(radians: 0.2)
                } label: {
                    Label("Right", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button {
                    Task {
                        await dismissImmersiveSpace()
                        session.phase = .closed
                    }
                } label: {
                    Label("Exit", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
            .controlSize(.regular)
        }
        .padding(18)
        .frame(minWidth: 380)
        .glassBackgroundEffect()
    }

    private var arrivalCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("You have arrived")
                .font(.largeTitle.weight(.bold))

            Text("Block 343, Yishun Ave 11")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Well done. Rest here, or exit the walk.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            HStack(spacing: 14) {
                Button("Stay a moment") {
                    session.dismissArrivalBanner()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button("Exit walk") {
                    Task {
                        await dismissImmersiveSpace()
                        session.phase = .closed
                        session.resetWalk()
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(28)
        .glassBackgroundEffect()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You have arrived at Block 343 Yishun Avenue 11")
    }

    // MARK: - Helpers

    private func applyWorldPose(to world: Entity) {
        world.orientation = session.worldOrientation()
        world.position = session.worldPosition()
    }

    private func hintForHandsStatus() -> String {
        switch hands.status {
        case .running:
            return "Left pinch = walk (hold to keep walking) · Right pinch = turn L/R"
        case .unsupported:
            return "Hand tracking unavailable here — use Step / Left / Right buttons"
        case .denied:
            return "Hands permission denied — use Step / Left / Right buttons"
        case .failed(let message):
            return "Hands failed (\(message)) — use buttons"
        case .idle:
            return "Starting hand tracking…"
        }
    }
}
