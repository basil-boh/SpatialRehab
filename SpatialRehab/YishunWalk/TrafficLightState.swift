import SwiftUI

/// Dementia-friendly signal phases. Cycles stay slow and predictable.
enum TrafficLightState: String, CaseIterable, Sendable, Identifiable {
    case red
    case yellow
    case green

    var id: String { rawValue }

    /// Primary coaching copy shown next to the map.
    var crossingPrompt: String {
        switch self {
        case .red: "Stop and Wait"
        case .yellow: "Get Ready"
        case .green: "Safe to Cross"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .red: "Red light. Stop and wait."
        case .yellow: "Yellow light. Get ready."
        case .green: "Green light. Safe to cross."
        }
    }

    var tint: Color {
        switch self {
        case .red: .red
        case .yellow: .yellow
        case .green: .green
        }
    }

    var systemImage: String {
        switch self {
        case .red: "hand.raised.fill"
        case .yellow: "exclamationmark.triangle.fill"
        case .green: "figure.walk"
        }
    }

    /// Next phase in a calm cycle: red → green → yellow → red.
    /// Yellow is a short caution after green, not a rapid flash.
    var next: TrafficLightState {
        switch self {
        case .red: .green
        case .green: .yellow
        case .yellow: .red
        }
    }

    /// Dwell time per phase (seconds). Long enough for unhurried decisions.
    var dwellSeconds: TimeInterval {
        switch self {
        case .red: 12
        case .green: 14
        case .yellow: 4
        }
    }
}
