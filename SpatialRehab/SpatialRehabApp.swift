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
            case .touchTheDots:
                TouchTheDotsSpaceView()
                    .environment(appModel)
            case .wayfinding:
                WayfindingSpaceView()
                    .environment(appModel)
            case .findHome:
                if #available(visionOS 26.0, *) {
                    FindHomeImmersiveView()
                        .environment(appModel)
                } else {
                    EmptyView()
                }
            case .routeMemory:
                RouteMemoryTableView()
                    .environment(appModel)
            }
        }
        .immersionStyle(
            selection: Binding(
                get: {
                    appModel.currentActivity == .findHome || appModel.routeMemoryInside
                        ? .full
                        : .mixed
                },
                set: { _ in }
            ),
            in: .mixed, .full
        )
    }
}
