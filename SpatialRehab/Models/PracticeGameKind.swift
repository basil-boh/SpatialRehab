import SwiftUI

/// The four practice game types shown on `DailyPracticeHubView`.
///
/// Same four games the baseline battery uses, reused rather than duplicated — see
/// `Docs/DailyPractice_Design.md`.
enum PracticeGameKind: String, CaseIterable, Codable, Identifiable {
    case wordMemory
    case patternMatching
    case arithmetic
    case clockDrawing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wordMemory: "Word Memory"
        case .patternMatching: "Matching Pairs"
        case .arithmetic: "Mental Sums"
        case .clockDrawing: "Draw & Trace"
        }
    }

    var iconName: String {
        switch self {
        case .wordMemory: "text.book.closed.fill"
        case .patternMatching: "square.grid.2x2.fill"
        case .arithmetic: "plus.forwardslash.minus"
        case .clockDrawing: "clock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wordMemory: .indigo
        case .patternMatching: .teal
        case .arithmetic: .orange
        case .clockDrawing: .pink
        }
    }

    /// Whether this game has an adaptive hidden difficulty tier. `false` only for
    /// `clockDrawing` — it still gets a `visibleLevel` like every other game, it just has no
    /// well-defined "harder" version and nothing to adapt from (no `score`). See
    /// `Docs/DailyPractice_Design.md`.
    var isDifficultyAdaptive: Bool {
        self != .clockDrawing
    }
}
