import SwiftUI

/// Welcome screen shown after the baseline assessment finishes.
///
/// The AR "Making Tea" guided task (previously launched from here via the immersive space)
/// is disabled on this branch while baseline-metrics is the active focus — see
/// `Docs/BaselineAssessment_Design.md`. `SpatialRehabApp` still declares the `ImmersiveSpace`
/// scene and owns `teaSession`, so that work isn't deleted, just not entered from here for
/// now. In its place, a dev-only button surfaces the raw data the baseline battery captured,
/// for verifying scoring/capture without leaving the app.
struct ContentView: View {
    @State private var showingBaselineResults = false

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

            Button("View Baseline Data (Dev)") {
                showingBaselineResults = true
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingBaselineResults) {
            BaselineResultsDebugView()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
