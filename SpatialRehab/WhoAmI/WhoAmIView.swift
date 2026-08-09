import SwiftUI

/// Dedicated “Who am I?” exercise: nest + circle summon (Simulator path supported).
struct WhoAmIView: View {
    @Environment(WhoAmISessionModel.self) private var session
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        @Bindable var session = session

        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 20) {
                Label("Who am I?", systemImage: "person.text.rectangle.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("Draw a circle to open your name card — a gentle reminder of who you are.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NestView(
                    glow: session.glowProgress,
                    isReceivingCard: session.phase == .puttingAway || session.phase == .nest
                )
                .overlay {
                    if session.phase == .presenting {
                        Text(DemoPersona.owner.emoji)
                            .font(.system(size: 48))
                            .offset(x: 40, y: -60)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    instructionRow("1", "Draw a circle (left hand / drag)")
                    instructionRow("2", "Name card glows open")
                    instructionRow("3", "Family → photos → short greeting")
                    instructionRow("4", "Put away → flies back to the nest")
                }
                .padding(.top, 8)

                Button {
                    session.summonWithButton()
                } label: {
                    Label("Summon name card", systemImage: "sparkles")
                        .font(.title3.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.orange)
                .controlSize(.large)
                .disabled(session.isCardWindowOpen && session.phase != .nest)

                if session.isCardWindowOpen {
                    Text("Name card is open")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 340, alignment: .leading)

            CircleDrawCanvas(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: session.isCardWindowOpen) { wasOpen, open in
            if open && !wasOpen {
                openWindow(id: "name-card")
            } else if !open && wasOpen {
                dismissWindow(id: "name-card")
            }
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .presenting, session.isCardWindowOpen {
                openWindow(id: "name-card")
            }
        }
    }

    private func instructionRow(_ step: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.orange.opacity(0.85)))
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

#Preview(windowStyle: .automatic) {
    WhoAmIView()
        .environment(WhoAmISessionModel())
}
