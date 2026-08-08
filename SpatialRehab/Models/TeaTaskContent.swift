import Foundation
import simd

/// Fixed layout of each placeholder marker relative to the detected tabletop anchor's
/// origin, in meters. `x`/`z` are along the table surface, `y` is height above it.
///
/// Values are a reasonable guess for a small side table, not measured — expect to tune
/// these once tested against a real tabletop in the simulator/device.
enum MarkerLayout {
    static let offsets: [MarkerObject: SIMD3<Float>] = [
        .kettle: SIMD3<Float>(-0.15, 0.06, -0.10),
        .cup: SIMD3<Float>(0.15, 0.04, -0.10),
    ]
}

/// Draft content for the first guided task: making a cup of tea.
///
/// See `Docs/TaskDesign_MakingTea.md` for the task-analysis rationale behind this exact
/// sequence — this is a first pass, not clinically reviewed.
enum TeaTaskContent {
    static let steps: [TaskStep] = [
        TaskStep(
            id: "tea.fillKettle",
            order: 1,
            title: "Fill the kettle",
            instructionText: "Fill the kettle with water.",
            spokenCue: "Fill the kettle with water.",
            markerObject: .kettle,
            isOptional: false,
            completionAffirmation: "Good — the kettle has water."
        ),
        TaskStep(
            id: "tea.turnOnKettle",
            order: 2,
            title: "Turn on the kettle",
            instructionText: "Turn on the kettle.",
            spokenCue: "Now turn on the kettle.",
            markerObject: .kettle,
            isOptional: false,
            completionAffirmation: "The kettle is heating up."
        ),
        TaskStep(
            id: "tea.teaBagInCup",
            order: 3,
            title: "Tea bag in cup",
            instructionText: "Put a tea bag in the cup.",
            spokenCue: "Put a tea bag in the cup.",
            markerObject: .cup,
            isOptional: false,
            completionAffirmation: "Tea bag is in the cup."
        ),
        TaskStep(
            id: "tea.waitForBoil",
            order: 4,
            title: "Wait for the water",
            instructionText: "Wait for the water to boil.",
            spokenCue: "Wait for the water to boil.",
            markerObject: .kettle,
            isOptional: false,
            completionAffirmation: "The water is ready."
        ),
        TaskStep(
            id: "tea.pourWater",
            order: 5,
            title: "Pour the water",
            instructionText: "Pour the hot water into the cup.",
            spokenCue: "Carefully pour the hot water into the cup.",
            markerObject: .cup,
            isOptional: false,
            completionAffirmation: "Nicely poured."
        ),
        TaskStep(
            id: "tea.addMilkSugar",
            order: 6,
            title: "Milk or sugar",
            instructionText: "Add milk or sugar, if you'd like.",
            spokenCue: "Add milk or sugar, if you would like some.",
            markerObject: .cup,
            isOptional: true,
            completionAffirmation: "All set."
        ),
        TaskStep(
            id: "tea.removeTeaBag",
            order: 7,
            title: "Take out the tea bag",
            instructionText: "Take the tea bag out.",
            spokenCue: "Now take the tea bag out.",
            markerObject: .cup,
            isOptional: false,
            completionAffirmation: "Tea bag removed."
        ),
        TaskStep(
            id: "tea.enjoy",
            order: 8,
            title: "Enjoy your tea",
            instructionText: "Enjoy your tea!",
            spokenCue: "All done. Enjoy your tea!",
            markerObject: .cup,
            isOptional: false,
            completionAffirmation: "Task complete."
        ),
    ]
}
