import Foundation

/// Result of a single digit-span trial: a fixed-length digit sequence is shown one digit at
/// a time, then the patient taps it back in order on a number pad.
///
/// Scored by position, not all-or-nothing — one misplaced digit doesn't zero the whole
/// trial, consistent with the gentler scoring used elsewhere in this battery.
struct DigitSpanResult: Codable, Hashable {
    let targetSequence: [Int]
    let enteredSequence: [Int]
    let completedAt: Date

    var score: Double {
        guard !targetSequence.isEmpty else { return 0 }
        let correctPositions = zip(targetSequence, enteredSequence).filter { $0 == $1 }.count
        return Double(correctPositions) / Double(targetSequence.count)
    }
}
