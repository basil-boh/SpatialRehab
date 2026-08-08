import MapKit
import SwiftUI

struct YishunWalkView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(WalkSessionModel.self) private var session
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            Group {
                switch session.loadState {
                case .idle, .loading:
                    loadingView
                case .failed(let message):
                    failedView(message)
                case .loaded:
                    loadedView
                }
            }
            .navigationTitle("Yishun Walk")
            .toolbar {
                if session.loadState == .loaded {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openWindow(id: "traffic-light-preview")
                        } label: {
                            Label("Signal preview", systemImage: "light.beacon.max.fill")
                        }
                        .buttonBorderShape(.capsule)
                    }
                }
            }
        }
        .task {
            await session.loadRouteIfNeeded()
            fitCameraToRoute()
        }
        .onChange(of: session.progress) { _, _ in
            guard session.followCamera else { return }
            withAnimation(.easeInOut(duration: 0.8)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: session.walkerCoordinate,
                        distance: 450,
                        heading: 0,
                        pitch: 55
                    )
                )
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Loading walking route…")
                .font(.title3)
            Text("\(YishunRoute.sourceTitle) → \(YishunRoute.destinationTitle)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Could not load route", systemImage: "map")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                Task {
                    await session.loadRoute()
                    fitCameraToRoute()
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }

    private var loadedView: some View {
        GeometryReader { proxy in
            let useWideLayout = proxy.size.width > 900

            if useWideLayout {
                HStack(alignment: .top, spacing: 20) {
                    mapColumn
                    sidePanel
                        .frame(width: min(380, proxy.size.width * 0.36))
                }
                .padding(20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        mapColumn
                            .frame(height: 360)
                        sidePanel
                    }
                    .padding(20)
                }
            }
        }
    }

    private var mapColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            YishunRouteMapView(session: session, cameraPosition: $cameraPosition)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 320)

            routeSummaryBar
            walkControls
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            CrossingPromptView(
                state: session.activeCrossingState,
                crossingName: session.selectedTrafficLight?.name
            )

            LookAroundWalkPanel(session: session)

            StepListView(steps: session.steps, currentStepIndex: session.currentStepIndex)

            Spacer(minLength: 0)
        }
    }

    private var routeSummaryBar: some View {
        @Bindable var session = session

        return HStack(spacing: 16) {
            Label(session.distanceDescription ?? "—", systemImage: "figure.walk")
            Label(session.travelTimeDescription ?? "—", systemImage: "clock")
            Text(session.progressDescription)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(isOn: $session.followCamera) {
                Text("Follow")
            }
            .toggleStyle(.button)
            .buttonBorderShape(.capsule)
        }
        .font(.callout)
        .padding(.horizontal, 4)
    }

    private var walkControls: some View {
        HStack(spacing: 12) {
            Button {
                if session.isWalking {
                    session.pauseWalking()
                } else {
                    session.startWalking()
                }
            } label: {
                Label(
                    session.isWalking ? "Pause" : "Start walk",
                    systemImage: session.isWalking ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
                session.previousStep()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
                session.nextStep()
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
                fitCameraToRoute()
                session.followCamera = false
            } label: {
                Label("Overview", systemImage: "map")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    private func fitCameraToRoute() {
        guard let route = session.route else {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: YishunRoute.fallbackSource,
                    latitudinalMeters: 1_200,
                    longitudinalMeters: 1_200
                )
            )
            return
        }

        let rect = route.polyline.boundingMapRect
        cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2))
    }
}

#Preview(windowStyle: .automatic) {
    YishunWalkView()
        .environment(WalkSessionModel())
}
