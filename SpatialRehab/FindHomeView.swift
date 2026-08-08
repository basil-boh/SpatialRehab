import MapKit
import SwiftUI

struct FindHomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var camera: MapCameraPosition = .automatic
    @State private var isGliding = false

    private var exercise: FindHomeExercise { appModel.findHome }

    var body: some View {
        VStack(spacing: 28) {
            Text(prompt)
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.center)

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if exercise.state == .junction {
                glideToCurrentJunction()
            }
        }
        .onChange(of: exercise.state) { _, newState in
            switch newState {
            case .junction where exercise.currentJunctionIndex == 0:
                glideToCurrentJunction()
            case .arrived:
                glide(to: FindHomeExercise.home, heading: 0, distance: 220)
            default:
                break
            }
        }
        .onChange(of: exercise.currentJunctionIndex) {
            glideToCurrentJunction()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch exercise.state {
        case .idle, .loading:
            ProgressView("Finding the way home…")
                .font(.title2)

        case .failed:
            VStack(spacing: 24) {
                Text("We couldn't load the walk right now.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    exercise.begin()
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
            }

        case .junction, .arrived:
            HStack(spacing: 16) {
                lookAroundCard
                mapCard
            }

            if exercise.state == .arrived {
                Button("Done") {
                    Task {
                        appModel.phase = .finished
                        await dismissImmersiveSpace()
                    }
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
            } else {
                arrows
            }
        }
    }

    private var lookAroundCard: some View {
        Group {
            if let scene = exercise.currentScene {
                LookAroundPreview(initialScene: scene)
                    .id(exercise.currentJunctionIndex)
            } else {
                ZStack {
                    Rectangle().fill(.thinMaterial)
                    ProgressView()
                }
            }
        }
        .frame(width: 460, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var mapCard: some View {
        Map(position: $camera) {
            if let route = exercise.route {
                MapPolyline(route.polyline)
                    .stroke(.cyan, lineWidth: 6)
            }
            Marker("Home", systemImage: "house.fill", coordinate: FindHomeExercise.home)
                .tint(.orange)
            Marker("Market", systemImage: "basket.fill", coordinate: FindHomeExercise.start)
                .tint(.green)
            if let junction = exercise.currentJunction {
                Annotation("You", coordinate: junction.coordinate) {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white, .blue)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(width: 330, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var arrows: some View {
        HStack(spacing: 28) {
            arrowButton(.left, symbol: "arrow.turn.up.left", title: "Turn left")
            arrowButton(.straight, symbol: "arrow.up", title: "Go straight")
            arrowButton(.right, symbol: "arrow.turn.up.right", title: "Turn right")
        }
    }

    private func arrowButton(
        _ turn: FindHomeExercise.Turn,
        symbol: String,
        title: String
    ) -> some View {
        Button {
            exercise.choose(turn)
        } label: {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .font(.system(size: 40, weight: .semibold))
                .frame(width: 96, height: 96)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .disabled(isGliding)
    }

    private var prompt: String {
        switch exercise.state {
        case .idle, .loading:
            return "Let's find our way home from the market."
        case .failed:
            return "Find Your Way Home"
        case .arrived:
            return "You found your way home!"
        case .junction:
            if isGliding {
                return "Off we go…"
            }
            return exercise.lastChoiceWrong
                ? "Let's have another look. Which way is home?"
                : "Which way is home?"
        }
    }

    private func glideToCurrentJunction() {
        guard let junction = exercise.currentJunction else { return }
        glide(to: junction.coordinate, heading: junction.outgoingHeading)
    }

    private func glide(to coordinate: CLLocationCoordinate2D, heading: Double, distance: Double = 320) {
        isGliding = true
        withAnimation(.easeInOut(duration: 2)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: distance,
                    heading: heading,
                    pitch: 55
                )
            )
        }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            isGliding = false
        }
    }
}
