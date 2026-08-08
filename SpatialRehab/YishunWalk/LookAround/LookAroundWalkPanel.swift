import MapKit
import SwiftUI

struct LookAroundWalkPanel: View {
    @Bindable var session: WalkSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Street view", systemImage: "binoculars.fill")
                .font(.headline)

            Group {
                if session.isLookAroundLoading {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.quaternary)
                        ProgressView("Loading street view…")
                    }
                } else if let scene = session.lookAroundScene {
                    LookAroundPreview(scene: .constant(scene))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ContentUnavailableView(
                        session.lookAroundUnavailable
                            ? "Street view not available here"
                            : "Street view",
                        systemImage: "eye.slash",
                        description: Text(
                            session.lookAroundUnavailable
                                ? "Keep following the map path. Imagery may appear further along the route."
                                : "Advance along the walk to load Apple Maps street imagery."
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .frame(minHeight: 180, maxHeight: 260)

            if session.lookAroundScene != nil {
                Button {
                    session.isPresentingLookAroundViewer = true
                } label: {
                    Label("Open full street view", systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .lookAroundViewer(
            isPresented: $session.isPresentingLookAroundViewer,
            initialScene: session.lookAroundScene
        )
    }
}
