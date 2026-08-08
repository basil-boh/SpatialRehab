import SwiftUI

/// Window UI to enter the first-person immersive walk and explain hand pinches.
struct ImmersiveWalkLaunchView: View {
    @Environment(ImmersiveWalkSession.self) private var session
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        @Bindable var session = session

        VStack(spacing: 28) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 64))
                .foregroundStyle(.teal)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 10) {
                Text("First-person walk")
                    .font(.largeTitle.weight(.semibold))

                Text("You are inside a virtual street. Walk to Block 343 with your hands — not Apple Maps street view.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            VStack(alignment: .leading, spacing: 14) {
                labelRow("hand.point.up.left.fill", "Left hand pinch — each pinch is a step; hold to keep walking")
                labelRow("hand.point.up.left", "Right hand pinch — move hand left/right to turn; hold to keep turning")
                labelRow("flag.checkered", "Reach the green door — “You have arrived”")
                labelRow("vision.pro", "Best on a real Vision Pro (Simulator has button fallback)")
            }
            .padding(20)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if session.hasArrived && session.phase == .open {
                Text("Destination reached — exit anytime.")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 16) {
                if session.phase == .open {
                    Button("Exit VR walk") {
                        Task {
                            await dismissImmersiveSpace()
                            session.phase = .closed
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                    Button("Restart from start") {
                        session.resetWalk()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                } else {
                    Button {
                        Task { await openWalk() }
                    } label: {
                        Label(
                            session.phase == .opening ? "Opening…" : "Enter VR walk",
                            systemImage: "vision.pro"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .disabled(session.phase == .opening)
                }
            }

            if session.phase == .failed {
                Text("Could not open the immersive space. Try again on Simulator or device.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if session.phase == .open {
                Text("Progress: \(session.progressPercent)%")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func labelRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(.teal)
            Text(text)
                .font(.body)
        }
    }

    private func openWalk() async {
        session.phase = .opening
        if session.hasArrived {
            session.resetWalk()
        }
        switch await openImmersiveSpace(id: "yishun-vr-walk") {
        case .opened:
            session.phase = .open
        case .userCancelled:
            session.phase = .closed
        case .error:
            session.phase = .failed
        @unknown default:
            session.phase = .failed
        }
    }
}

#Preview(windowStyle: .automatic) {
    ImmersiveWalkLaunchView()
        .environment(ImmersiveWalkSession())
}
