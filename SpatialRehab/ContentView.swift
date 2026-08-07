import SwiftUI

/// Main window: lets the person start the guided task and shows the current instruction
/// once it's running. Stays open alongside the immersive space (visionOS supports both at
/// once) so the instruction card is always in a predictable, user-repositionable window
/// rather than pinned in 3D space.
struct ContentView: View {
    @ObservedObject var session: TaskSession

    @State private var isImmersiveSpaceOpen = false
    @State private var isOpeningImmersiveSpace = false
    @State private var immersiveSpaceErrorMessage: String?
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 28) {
            Text("SpatialRehab")
                .font(.largeTitle.bold())

            Text("Prototype: Making a Cup of Tea")
                .foregroundStyle(.secondary)

            if isImmersiveSpaceOpen {
                GuidanceCardView(session: session)
            } else {
                Button(isOpeningImmersiveSpace ? "Starting…" : "Start Guided Task") {
                    Task { await startImmersiveSpace() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .disabled(isOpeningImmersiveSpace)

                // Surfaced instead of silently doing nothing — a failed/cancelled
                // openImmersiveSpace() used to leave the screen looking unchanged, which
                // was indistinguishable from the tap not registering at all.
                if let immersiveSpaceErrorMessage {
                    Text(immersiveSpaceErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            if isImmersiveSpaceOpen {
                Button("End Task", role: .destructive) {
                    Task { await endImmersiveSpace() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }

    private func startImmersiveSpace() async {
        session.reset()
        immersiveSpaceErrorMessage = nil
        isOpeningImmersiveSpace = true
        let result = await openImmersiveSpace(id: ImmersiveSpaceID.teaTask)
        isOpeningImmersiveSpace = false
        switch result {
        case .opened:
            isImmersiveSpaceOpen = true
        case .userCancelled:
            immersiveSpaceErrorMessage = "Cancelled — tap Start Guided Task to try again."
        case .error:
            immersiveSpaceErrorMessage = "Couldn't start the guided task. Check Xcode's console for the underlying error, and that Hand Tracking / World Sensing permissions weren't denied in Settings."
        @unknown default:
            immersiveSpaceErrorMessage = "Something unexpected happened opening the guided task."
        }
    }

    private func endImmersiveSpace() async {
        await dismissImmersiveSpace()
        isImmersiveSpaceOpen = false
    }
}

#Preview(windowStyle: .automatic) {
    ContentView(session: TaskSession(steps: TeaTaskContent.steps))
}
