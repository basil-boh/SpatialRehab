import SwiftUI

struct ContentView: View {
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

            Button("Get Started") {}
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
