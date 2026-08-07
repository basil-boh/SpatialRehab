import SwiftUI

/// Welcome screen leads into the guided task. The window stays open alongside the
/// immersive space (visionOS supports both at once) so the instruction card is always in a
/// predictable, user-repositionable window rather than pinned in 3D space.
struct ContentView: View {
    @ObservedObject var session: TaskSession

    @State private var isImmersiveSpaceOpen = false
    @State private var isOpeningImmersiveSpace = false
    @State private var immersiveSpaceErrorMessage: String?
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 28) {
            if isImmersiveSpaceOpen {
                GuidanceCardView(session: session)

                Button("End Task", role: .destructive) {
                    Task { await endImmersiveSpace() }
                }
                .buttonStyle(.bordered)
            } else {
                welcomeContent
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeContent: some View {
        VStack(spacing: 40) {
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Welcome to SpatialRehab")
                    .font(.system(size: 44, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("A calm companion to help you remember home, your medication, and your daily routine.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                Text("Prototype: Making a Cup of Tea")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Button(isOpeningImmersiveSpace ? "Starting…" : "Get Started") {
                Task { await startImmersiveSpace() }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .disabled(isOpeningImmersiveSpace)

            // Surfaced instead of silently doing nothing — a failed/cancelled
            // openImmersiveSpace() used to leave the screen looking unchanged, which was
            // indistinguishable from the tap not registering at all.
            if let immersiveSpaceErrorMessage {
                Text(immersiveSpaceErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
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
            immersiveSpaceErrorMessage = "Cancelled — tap Get Started to try again."
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
