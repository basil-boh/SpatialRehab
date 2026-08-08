import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
            }

            VStack(spacing: 16) {
                Button("Who am I?") {
                    openWindow(id: "who-am-i")
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .tint(.orange)

                Text("Draw a circle · name card · family greetings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Walk in VR (first person)") {
                    openWindow(id: "yishun-vr-launch")
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Text("Left pinch walk · Right pinch turn · Arrive at Block 343")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Yishun Map (overview only)") {
                    openWindow(id: "yishun-walk")
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Button("Hummingbird") {
                    openWindow(id: "hummingbird")
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
