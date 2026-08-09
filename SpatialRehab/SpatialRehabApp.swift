import SwiftUI

@main
struct SpatialRehabApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 900, height: 600)

        ImmersiveSpace(id: AppModel.activitySpaceID) {
            switch appModel.currentActivity {
            case .routeMemory:
                RouteMemoryTableView()
                    .environment(appModel)
            case .coffee:
                CoffeeActivityView()
                    .environment(appModel)
            case .mahjong:
                MahjongActivityView()
                    .environment(appModel)
            }
        }
        .immersionStyle(
            selection: Binding(
                get: { appModel.routeMemoryInside ? .full : .mixed },
                set: { _ in }
            ),
            in: .mixed, .full
        )
    }
}
