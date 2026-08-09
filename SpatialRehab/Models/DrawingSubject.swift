import Foundation

/// One "what to draw" prompt for the drawing game.
///
/// The clock (`DrawingSubjects.all[0]`) is free-recall with no reference shown — that's the
/// original baseline Clock Drawing Test format, unchanged. Everything after it shows an SF
/// Symbol silhouette as a traceable outline instead: a gentler, more accessible mechanic than
/// pure recall for this audience, and it doubles as object naming/recognition practice —
/// "jog their memory for common items," per the product ask. See
/// `Docs/DailyPractice_Design.md`.
struct DrawingSubject: Identifiable, Equatable {
    let id: String
    let promptText: String

    /// SF Symbol name for the traceable outline. `nil` only for the clock.
    let outlineSymbolName: String?
}

enum DrawingSubjects {
    /// Order matters: index 0 (the clock) is always level 1. Everything after cycles through
    /// common, concrete, easily nameable animals and everyday objects — verified against the
    /// installed SDK to exist as real SF Symbols before use, not assumed from memory. Sized
    /// to 30 total (matching the 1–30 scale the other three games use) rather than the
    /// original 11 — see `Docs/DailyPractice_Design.md`.
    static let all: [DrawingSubject] = [
        DrawingSubject(id: "clock", promptText: "Draw a clock showing ten past eleven.", outlineSymbolName: nil),
        DrawingSubject(id: "dog", promptText: "Trace the dog.", outlineSymbolName: "dog.fill"),
        DrawingSubject(id: "cat", promptText: "Trace the cat.", outlineSymbolName: "cat.fill"),
        DrawingSubject(id: "house", promptText: "Trace the house.", outlineSymbolName: "house.fill"),
        DrawingSubject(id: "tree", promptText: "Trace the tree.", outlineSymbolName: "tree.fill"),
        DrawingSubject(id: "sun", promptText: "Trace the sun.", outlineSymbolName: "sun.max.fill"),
        DrawingSubject(id: "fish", promptText: "Trace the fish.", outlineSymbolName: "fish.fill"),
        DrawingSubject(id: "car", promptText: "Trace the car.", outlineSymbolName: "car.fill"),
        DrawingSubject(id: "cup", promptText: "Trace the cup.", outlineSymbolName: "cup.and.saucer.fill"),
        DrawingSubject(id: "umbrella", promptText: "Trace the umbrella.", outlineSymbolName: "umbrella.fill"),
        DrawingSubject(id: "key", promptText: "Trace the key.", outlineSymbolName: "key.fill"),
        DrawingSubject(id: "phone", promptText: "Trace the telephone.", outlineSymbolName: "phone.fill"),
        DrawingSubject(id: "envelope", promptText: "Trace the letter.", outlineSymbolName: "envelope.fill"),
        DrawingSubject(id: "bag", promptText: "Trace the bag.", outlineSymbolName: "bag.fill"),
        DrawingSubject(id: "forkKnife", promptText: "Trace the fork and knife.", outlineSymbolName: "fork.knife"),
        DrawingSubject(id: "book", promptText: "Trace the book.", outlineSymbolName: "book.closed.fill"),
        DrawingSubject(id: "bell", promptText: "Trace the bell.", outlineSymbolName: "bell.fill"),
        DrawingSubject(id: "lightbulb", promptText: "Trace the lightbulb.", outlineSymbolName: "lightbulb.fill"),
        DrawingSubject(id: "scissors", promptText: "Trace the scissors.", outlineSymbolName: "scissors"),
        DrawingSubject(id: "eyeglasses", promptText: "Trace the glasses.", outlineSymbolName: "eyeglasses"),
        DrawingSubject(id: "shirt", promptText: "Trace the shirt.", outlineSymbolName: "tshirt.fill"),
        DrawingSubject(id: "suitcase", promptText: "Trace the suitcase.", outlineSymbolName: "suitcase.fill"),
        DrawingSubject(id: "bed", promptText: "Trace the bed.", outlineSymbolName: "bed.double.fill"),
        DrawingSubject(id: "shoe", promptText: "Trace the shoe.", outlineSymbolName: "shoe.fill"),
        DrawingSubject(id: "comb", promptText: "Trace the comb.", outlineSymbolName: "comb.fill"),
        DrawingSubject(id: "bathtub", promptText: "Trace the bathtub.", outlineSymbolName: "bathtub.fill"),
        DrawingSubject(id: "fan", promptText: "Trace the fan.", outlineSymbolName: "fan.fill"),
        DrawingSubject(id: "backpack", promptText: "Trace the backpack.", outlineSymbolName: "backpack.fill"),
        DrawingSubject(id: "camera", promptText: "Trace the camera.", outlineSymbolName: "camera.fill"),
        DrawingSubject(id: "bicycle", promptText: "Trace the bicycle.", outlineSymbolName: "bicycle"),
    ]

    /// Deterministic level → subject: level 1 is always the clock; every level after cycles
    /// through the rest of the list (29 objects, so levels 2–30 are each subject exactly
    /// once), repeating from the top once exhausted.
    static func subject(forLevel level: Int) -> DrawingSubject {
        guard level > 1 else { return all[0] }
        let rest = Array(all.dropFirst())
        return rest[(level - 2) % rest.count]
    }

    /// How many times the full object cycle has been completed by `level` — 0 for the first
    /// pass (levels 2–30), 1 for the second (levels 31–59), and so on. Drives the outline
    /// fading in `outlineOpacity(forLevel:)`: the same "vanishing cues" idea used in
    /// dementia-care memory training — start with a clear prompt, then gradually withdraw it
    /// as the response strengthens, rather than making the *shape itself* harder (which isn't
    /// really a well-defined axis for a silhouette). See `Docs/DailyPractice_Design.md`.
    static func cyclePassNumber(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let rest = all.count - 1
        return (level - 2) / rest
    }

    /// Outline opacity for this level: full on the first pass through the object list, fading
    /// a little on each subsequent pass, floored well above zero so tracing stays achievable
    /// — this is meant to feel like less hand-holding over time, never like the guide
    /// vanishing and leaving them stuck.
    static func outlineOpacity(forLevel level: Int) -> Double {
        let pass = cyclePassNumber(forLevel: level)
        return max(0.06, 0.25 - Double(pass) * 0.05)
    }
}
