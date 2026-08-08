import RealityKit
import SwiftUI

struct TrafficLightVolumeView: View {
    @Environment(WalkSessionModel.self) private var session

    var body: some View {
        VStack(spacing: 20) {
            Text(session.selectedTrafficLight?.name ?? "Traffic signal")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(session.activeCrossingPrompt)
                .font(.title3)
                .foregroundStyle(session.activeCrossingState.tint)

            RealityView { content in
                let light = TrafficLightEntity()
                light.scale = SIMD3(repeating: 0.9)
                light.position = [0, -0.15, 0]
                content.add(light)
            } update: { content in
                guard let light = content.entities.first as? TrafficLightEntity else { return }
                light.updateLightState(session.activeCrossingState)
            }
            .frame(depth: 0.4)

            Text("Placeholder model — named RedLight / YellowLight / GreenLight for a future USDZ swap.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
    }
}

#Preview(windowStyle: .volumetric) {
    TrafficLightVolumeView()
        .environment(WalkSessionModel())
}
