import SwiftUI

struct CrossingPromptView: View {
    let state: TrafficLightState
    let crossingName: String?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: state.systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(state.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.crossingPrompt)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                if let crossingName {
                    Text(crossingName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(state == .green
                     ? "Look both ways, then walk carefully."
                     : "Wait on the sidewalk until it is safe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(state.tint.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }
}
