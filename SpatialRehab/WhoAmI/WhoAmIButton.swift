import SwiftUI

/// The persistent "Who am I?" action: presents the name card so a person can reorient
/// themselves (who they are, who their family is) at any point. Hosted in two places so
/// it is always within reach outside the baseline assessment — as a bottom ornament on
/// the main window, and inside `RouteMemoryTableView`'s control panel, which is the only
/// surface left on screen while that activity runs (the main window is dismissed).
/// Reads `WhoAmISessionModel` from the environment; both hosting scenes inject it in
/// `SpatialRehabApp`.
struct WhoAmIButton: View {
    @Environment(WhoAmISessionModel.self) private var whoAmISession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            whoAmISession.present()
            openWindow(id: SceneID.nameCard)
        } label: {
            Label("Who am I?", systemImage: "person.crop.circle")
                .font(.title3)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(.orange)
    }
}

#Preview {
    WhoAmIButton()
        .environment(WhoAmISessionModel())
        .padding(12)
        .glassBackgroundEffect()
}
