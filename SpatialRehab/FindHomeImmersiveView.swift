import MapKit
import RealityKit
import SwiftUI
import UIKit

/// Pre-generates and caches spatial scenes from street snapshots so the
/// immersive street appears instantly when the activity starts.
@available(visionOS 26.0, *)
@MainActor
final class SpatialStreetCache {
    static let shared = SpatialStreetCache()

    private var tasks: [URL: Task<ImagePresentationComponent.Spatial3DImage?, Never>] = [:]

    func warm(_ urls: [URL]) {
        for url in urls {
            _ = generationTask(for: url)
        }
    }

    func spatialImage(for url: URL) async -> ImagePresentationComponent.Spatial3DImage? {
        await generationTask(for: url).value
    }

    private func generationTask(for url: URL) -> Task<ImagePresentationComponent.Spatial3DImage?, Never> {
        if let existing = tasks[url] {
            return existing
        }
        let task = Task { () -> ImagePresentationComponent.Spatial3DImage? in
            do {
                let image = try await ImagePresentationComponent.Spatial3DImage(contentsOf: url)
                try await image.generate()
                return image
            } catch {
                return nil
            }
        }
        tasks[url] = task
        return task
    }
}

/// Loads equirectangular panoramas for the inside-a-sphere street view.
/// Partial-FOV captures (phone panoramas, stitched cameras) get letterboxed
/// to the required 2:1 with smeared edge rows.
@MainActor
enum PanoramaLoader {
    static func texture(from url: URL) async -> TextureResource? {
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let padded = pad(image) ?? image
        return try? await TextureResource(image: padded, options: .init(semantic: .color))
    }

    private static func pad(_ image: CGImage) -> CGImage? {
        let width = image.width
        let targetHeight = width / 2
        guard image.height < targetHeight else { return image }
        guard let context = CGContext(
            data: nil, width: width, height: targetHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let y = (targetHeight - image.height) / 2
        if let bottomRow = image.cropping(to: CGRect(x: 0, y: image.height - 1, width: width, height: 1)) {
            context.draw(bottomRow, in: CGRect(x: 0, y: 0, width: width, height: y))
        }
        if let topRow = image.cropping(to: CGRect(x: 0, y: 0, width: width, height: 1)) {
            context.draw(
                topRow,
                in: CGRect(x: 0, y: y + image.height, width: width, height: targetHeight - y - image.height)
            )
        }
        context.draw(image, in: CGRect(x: 0, y: y, width: width, height: image.height))
        return context.makeImage()
    }
}

/// Apple's live 3D Flyover map rendered as a giant tilted board the patient
/// stands over; the camera swoops along the walking route between junctions.
@available(visionOS 26.0, *)
struct FlyoverMapView: View {
    @Environment(AppModel.self) private var appModel

    @State private var camera: MapCameraPosition = .automatic

    private var exercise: FindHomeExercise { appModel.findHome }

    var body: some View {
        Map(position: $camera, interactionModes: []) {
            if let route = exercise.route {
                MapPolyline(route.polyline)
                    .stroke(.cyan, lineWidth: 8)
            }
            Marker("Home", systemImage: "house.fill", coordinate: FindHomeExercise.home)
                .tint(.orange)
            Marker("Market", systemImage: "basket.fill", coordinate: FindHomeExercise.start)
                .tint(.green)
            if let junction = exercise.currentJunction {
                Annotation("You", coordinate: junction.coordinate) {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white, .blue)
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .onAppear {
            glideToCurrentJunction(animated: false)
        }
        .onChange(of: exercise.currentJunctionIndex) {
            glideToCurrentJunction(animated: true)
        }
        .onChange(of: exercise.state) { _, newState in
            if newState == .arrived {
                glide(to: FindHomeExercise.home, heading: 0, distance: 200, animated: true)
            }
        }
    }

    private func glideToCurrentJunction(animated: Bool) {
        guard let junction = exercise.currentJunction else { return }
        glide(
            to: junction.coordinate,
            heading: junction.outgoingHeading,
            distance: 320,
            animated: animated
        )
    }

    private func glide(
        to coordinate: CLLocationCoordinate2D,
        heading: Double,
        distance: Double,
        animated: Bool
    ) {
        let target = MapCameraPosition.camera(
            MapCamera(centerCoordinate: coordinate, distance: distance, heading: heading, pitch: 70)
        )
        if animated {
            withAnimation(.easeInOut(duration: 2.5)) { camera = target }
        } else {
            camera = target
        }
    }
}

/// Full-immersion Find Home stage: a life-size 3D mesh of the real
/// neighborhood (OpenStreetMap footprints and heights) built around the
/// patient. They stand at each junction facing their direction of travel,
/// with the walked route glowing behind them and an orange beacon over home.
/// The arrow controls stay in the main window.
@available(visionOS 26.0, *)
struct FindHomeImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    @State private var controller = NeighborhoodController()
    @State private var placedIndex = Int.min

    var body: some View {
        RealityView { content in
            content.add(controller.root)
        }
        .task(id: appModel.findHome.state) {
            await sync()
        }
        .task(id: appModel.findHome.currentJunctionIndex) {
            await sync()
        }
        .onDisappear {
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    private func sync() async {
        let exercise = appModel.findHome
        switch exercise.state {
        case .junction:
            guard let junction = exercise.currentJunction else { return }
            await controller.buildIfNeeded(route: exercise.route)
            let index = exercise.currentJunctionIndex
            guard index != placedIndex else { return }
            let animated = placedIndex != Int.min
            placedIndex = index
            await controller.move(
                to: junction.coordinate,
                heading: junction.incomingHeading,
                traveledLegs: index + 1,
                animated: animated
            )
        case .arrived:
            await controller.buildIfNeeded(route: exercise.route)
            guard placedIndex != Int.max else { return }
            placedIndex = Int.max
            await controller.move(
                to: FindHomeExercise.home,
                heading: exercise.junctions.last?.outgoingHeading ?? 0,
                traveledLegs: Int.max,
                animated: true
            )
        default:
            break
        }
    }
}
