import SwiftUI

@main
struct SpatialRehabApp: App {
    @State private var walkSession = WalkSessionModel()
    @State private var immersiveWalk = ImmersiveWalkSession()
    @State private var whoAmISession = WhoAmISessionModel()
    @State private var immersionStyle: ImmersionStyle = .full

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(immersiveWalk)
        }
        .defaultSize(width: 900, height: 600)

        WindowGroup(id: "hummingbird") {
            HummingbirdVolumeView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)

        WindowGroup(id: "yishun-walk") {
            YishunWalkView()
                .environment(walkSession)
        }
        .defaultSize(width: 1280, height: 840)

        WindowGroup(id: "traffic-light-preview") {
            TrafficLightVolumeView()
                .environment(walkSession)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.45, height: 0.55, depth: 0.45, in: .meters)

        WindowGroup(id: "yishun-vr-launch") {
            ImmersiveWalkLaunchView()
                .environment(immersiveWalk)
        }
        .defaultSize(width: 720, height: 640)

        ImmersiveSpace(id: "yishun-vr-walk") {
            ImmersiveWalkSpaceView()
                .environment(immersiveWalk)
        }
        .immersionStyle(selection: $immersionStyle, in: .full)

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
