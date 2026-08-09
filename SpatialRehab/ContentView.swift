import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        VStack(spacing: 40) {
            switch appModel.phase {
            case .welcome, .openingActivity:
                welcome
            case .inActivity:
                inActivity
            case .finished:
                finished
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcome: some View {
        VStack(spacing: 40) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            Text("What shall we do today?")
                .font(.system(size: 44, weight: .semibold))

            VStack(spacing: 20) {
                Button {
                    Task { await startActivity(.routeMemory) }
                } label: {
                    Label("Remember the Way", systemImage: "map.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)

                Button {
                    Task { await startActivity(.coffee) }
                } label: {
                    Label("Make a Cup of Kopi", systemImage: "cup.and.saucer.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)

                Button {
                    Task { await startActivity(.mahjong) }
                } label: {
                    Label("Play Mahjong Pairs", systemImage: "square.grid.3x3.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)
            }
        }
    }

    private var inActivity: some View {
        VStack(spacing: 16) {
            Text("Look at the table")
                .font(.system(size: 44, weight: .semibold))

            Text(inActivityGuidance)
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var finished: some View {
        VStack(spacing: 40) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Well done!")
                    .font(.system(size: 44, weight: .semibold))

                Text("You did wonderfully. See you again soon.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Play again") {
                Task { await startActivity(appModel.currentActivity) }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
    }

    private var inActivityGuidance: String {
        switch appModel.currentActivity {
        case .routeMemory:
            return "Study the glowing route, then find the way home from memory."
        case .coffee:
            return "Follow the glowing tags and make your kopi, one step at a time."
        case .mahjong:
            return "Pick up a tile and place it beside its twin."
        }
    }

    private func startActivity(_ activity: AppModel.ActivityKind) async {
        appModel.phase = .openingActivity
        appModel.currentActivity = activity
        switch activity {
        case .routeMemory:
            appModel.routeMemory.begin()
        case .coffee:
            appModel.coffee.begin()
        case .mahjong:
            appModel.mahjong.begin()
        }
        switch await openImmersiveSpace(id: AppModel.activitySpaceID) {
        case .opened:
            appModel.phase = .inActivity
        case .userCancelled, .error:
            appModel.phase = .welcome
        @unknown default:
            appModel.phase = .welcome
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
