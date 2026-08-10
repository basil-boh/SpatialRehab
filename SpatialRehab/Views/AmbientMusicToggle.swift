import SwiftUI

/// Turns the ambient music bed on and off. Hosted in the same two places the "Who am I?"
/// button is — the main window's bottom ornament and `RouteMemoryTableView`'s control panel
/// — so music can be silenced from wherever the person happens to be, including mid-activity
/// when the main window is gone.
///
/// Reads `AmbientMusic.shared` directly rather than taking it from the environment. There is
/// exactly one bed for the whole process, and this control has to work inside the immersive
/// space as well as the window, so threading it through every scene's environment would buy
/// nothing. Observation still tracks the read, so the icon flips when the state does.
///
/// Untinted as of 2026-08-10. It used to run a saturated teal beside the "Who am I?"
/// button's saturated orange, which gave a mute switch the same visual claim as the
/// reorientation lifeline. `RehabTint` now reserves orange for that button alone; this one
/// says what it is through the icon. The slash is the state — plus a bounce on the change,
/// so a toggle you may have pressed by accident is visibly a toggle.
struct AmbientMusicToggle: View {
    /// Matches the 54×54 circular buttons in `RouteMemoryTableView`'s control panel; the
    /// default capsule-with-label form is used where there is room for a label.
    var iconOnly = false

    var body: some View {
        let isOn = AmbientMusic.shared.isEnabled
        Button {
            AmbientMusic.shared.toggle()
        } label: {
            label(isOn: isOn)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(iconOnly ? .circle : .capsule)
        .controlSize(iconOnly ? .regular : .large)
        .accessibilityLabel(isOn ? "Turn music off" : "Turn music on")
    }

    // Branching rather than erasing the label style: SwiftUI has no `AnyLabelStyle`, so the
    // two forms have to be separate views.
    @ViewBuilder
    private func label(isOn: Bool) -> some View {
        let content = Label(
            isOn ? "Music on" : "Music off",
            systemImage: isOn ? "music.note" : "music.note.slash"
        )
        .font(.title3)
        .contentTransition(.symbolEffect(.replace))
        .symbolEffect(.bounce, options: .nonRepeating, value: isOn)

        if iconOnly {
            content
                .labelStyle(.iconOnly)
                .frame(width: 54, height: 54)
        } else {
            content
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AmbientMusicToggle()
        AmbientMusicToggle(iconOnly: true)
    }
    .padding(12)
    .glassBackgroundEffect()
}
