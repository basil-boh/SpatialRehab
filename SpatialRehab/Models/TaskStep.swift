import Foundation

/// The real-world object a step's spatial marker should highlight.
///
/// Only two placeholder objects exist for the "Making Tea" prototype. Position/appearance
/// for each case lives in `MarkerLayout` (see `TeaTaskContent.swift`) rather than here, so
/// this type stays a plain identifier.
enum MarkerObject: String, Codable, Hashable {
    case kettle
    case cup
}

/// A single step in a guided daily-living task.
///
/// Design intent (see `Docs/TaskDesign_MakingTea.md`): one action per step, plain-language
/// instruction, a spoken-cue variant, and enough shape here that a later version can add
/// prompt escalation without reworking the model.
struct TaskStep: Identifiable, Codable, Hashable {
    let id: String
    let order: Int

    /// Short label, e.g. for the progress list. Not shown as the primary instruction.
    let title: String

    /// The single-sentence, present-tense instruction shown on the guidance card.
    let instructionText: String

    /// Same content as `instructionText`, phrased for text-to-speech. Kept separate because
    /// spoken phrasing sometimes needs to differ slightly from on-screen text for clarity.
    let spokenCue: String

    /// Which placeholder object this step's spatial marker should highlight.
    let markerObject: MarkerObject

    /// Optional steps (e.g. "add milk or sugar") can be skipped with one tap instead of
    /// being posed as a decision the person has to reason through.
    let isOptional: Bool

    /// Short affirmation shown after this step is marked done. Kept step-specific (rather
    /// than one generic "Nice work!") so completing the whole task feels like a sequence of
    /// small wins, per errorless-learning framing.
    let completionAffirmation: String
}
