import CoreLocation
import MapKit
import SwiftUI

struct StepListView: View {
    let steps: [MKRoute.Step]
    let currentStepIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Directions")
                .font(.headline)

            if steps.isEmpty {
                Text("Walking steps will appear when the route loads.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: index == currentStepIndex
                                      ? "location.circle.fill"
                                      : "circle")
                                    .foregroundStyle(index == currentStepIndex ? .teal : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.instructions.isEmpty ? "Continue" : step.instructions)
                                        .font(index == currentStepIndex ? .body.weight(.semibold) : .body)
                                        .foregroundStyle(index == currentStepIndex ? .primary : .secondary)
                                    if step.distance > 0 {
                                        Text(distanceText(step.distance))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .accessibilityLabel(accessibilityText(for: step, index: index))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func distanceText(_ meters: CLLocationDistance) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return Self.formatter.string(from: measurement)
    }

    private func accessibilityText(for step: MKRoute.Step, index: Int) -> String {
        let instruction = step.instructions.isEmpty ? "Continue" : step.instructions
        let prefix = index == currentStepIndex ? "Current step: " : "Step \(index + 1): "
        return prefix + instruction
    }

    private static let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()
}
