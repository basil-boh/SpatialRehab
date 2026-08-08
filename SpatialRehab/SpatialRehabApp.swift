import SwiftUI

@main
struct SpatialRehabApp: App {
    @State private var whoAmISession = WhoAmISessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)

        WindowGroup(id: "hummingbird") {
            HummingbirdVolumeView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)

        // “Who am I?” — nest + circle summon (name card opens as a second window).
        WindowGroup(id: "who-am-i") {
            WhoAmIView()
                .environment(whoAmISession)
        }
        .defaultSize(width: 1100, height: 720)

        WindowGroup(id: "name-card") {
            NameCardView(session: whoAmISession)
        }
        .defaultSize(width: 640, height: 560)
    }
}
