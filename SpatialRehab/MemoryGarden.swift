import Observation
import RealityKit
import SwiftUI

// MARK: - Accent palette

/// One restrained accent family over system materials — jade for growth,
/// amber for reward, nothing louder. Text stays `.primary`/`.secondary` so
/// the windows read as native visionOS product surfaces.
enum GardenAccent {
    static let jade = Color(red: 0.22, green: 0.62, blue: 0.52)
    static let jadeDeep = Color(red: 0.05, green: 0.18, blue: 0.16)
    static let ink = Color(red: 0.03, green: 0.08, blue: 0.08)
    static let amber = Color(red: 0.95, green: 0.72, blue: 0.30)
    static let mist = Color(red: 0.75, green: 0.88, blue: 0.84)
}

// MARK: - Keepsakes

/// One minted keepsake per completed activity — the album doubles as the
/// patient-facing progress record (never a score, always a memory).
struct Postcard: Codable, Identifiable, Equatable {
    let id: UUID
    let activityRaw: String
    let dateText: String
    let line: String
    let points: Int

    var symbolName: String {
        switch activityRaw {
        case "kopi": return "cup.and.saucer.fill"
        case "mahjong": return "square.grid.3x3.fill"
        default: return "map.fill"
        }
    }

    var title: String {
        switch activityRaw {
        case "kopi": return "A cup of kopi"
        case "mahjong": return "An afternoon of mahjong"
        default: return "The way home"
        }
    }
}

/// The growing garden: activity completions become lights in the garden.
/// Counts only ever rise — growth without loss, by design.
@Observable
@MainActor
final class GardenStore {
    private(set) var kopiCount: Int
    private(set) var mahjongCount: Int
    private(set) var routeCount: Int
    private(set) var coins: Int
    private(set) var postcards: [Postcard]

    private static let defaultsKey = "memoryGarden.v1"

    private struct Snapshot: Codable {
        var kopi: Int
        var mahjong: Int
        var route: Int
        var coins: Int
        var postcards: [Postcard]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            kopiCount = snapshot.kopi
            mahjongCount = snapshot.mahjong
            routeCount = snapshot.route
            coins = snapshot.coins
            postcards = snapshot.postcards
        } else {
            kopiCount = 0
            mahjongCount = 0
            routeCount = 0
            coins = 0
            postcards = []
        }
    }

    var totalGrowth: Int { kopiCount + mahjongCount + routeCount }

    @discardableResult
    func record(activity: AppModel.ActivityKind, points: Int) -> Postcard {
        let raw: String
        let line: String
        switch activity {
        case .coffee:
            kopiCount += 1
            raw = "kopi"
            line = "Brewed with your own two hands."
        case .mahjong:
            mahjongCount += 1
            raw = "mahjong"
            line = "Four sets and a pair — beautifully played."
        case .routeMemory:
            routeCount += 1
            raw = "way"
            line = "You remembered the way home."
        }
        coins += max(points, 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let postcard = Postcard(
            id: UUID(),
            activityRaw: raw,
            dateText: formatter.string(from: .now),
            line: line,
            points: max(points, 1)
        )
        postcards.append(postcard)
        save()
        return postcard
    }

    private func save() {
        let snapshot = Snapshot(
            kopi: kopiCount, mahjong: mahjongCount, route: routeCount,
            coins: coins, postcards: postcards
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

// MARK: - Ambience

/// Loads a bundled animated USDZ, normalizes its size, and loops any baked
/// animation it carries. Sole current use: the mahjong table's red lantern.
enum Ambience {
    static func load(_ name: String, width: Float? = nil, height: Float? = nil) async -> Entity? {
        guard let entity = try? await Entity(named: name) else { return nil }
        let bounds = entity.visualBounds(relativeTo: nil)
        let scale: Float
        if let width {
            scale = width / max(bounds.extents.x, 0.001)
        } else if let height {
            scale = height / max(bounds.extents.y, 0.001)
        } else {
            scale = 1
        }
        entity.scale = SIMD3(repeating: scale)
        for animation in entity.availableAnimations {
            entity.playAnimation(animation.repeat())
        }
        return entity
    }
}

// MARK: - Moment cards

struct PostcardView: View {
    let postcard: Postcard
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack(spacing: compact ? 10 : 14) {
                Image(systemName: postcard.symbolName)
                    .font(.system(size: compact ? 15 : 22, weight: .semibold))
                    .foregroundStyle(GardenAccent.jade)
                    .frame(width: compact ? 34 : 48, height: compact ? 34 : 48)
                    .background(GardenAccent.jade.opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 9 : 12))
                Text(postcard.title)
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                Spacer(minLength: 0)
            }
            Text(postcard.line)
                .font(compact ? .caption : .body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                Text(postcard.dateText)
                    .font(compact ? .caption2 : .footnote)
                    .foregroundStyle(.tertiary)
                Spacer()
                Label("\(postcard.points)", systemImage: "star.fill")
                    .font(compact ? .caption2.weight(.semibold) : .footnote.weight(.semibold))
                    .foregroundStyle(GardenAccent.amber)
            }
        }
        .padding(compact ? 14 : 22)
        .frame(width: compact ? 230 : 380, height: compact ? 128 : 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

/// The mint moment: the card springs in under a brief, restrained shimmer.
struct PostcardMintView: View {
    let postcard: Postcard
    @State private var arrived = false

    var body: some View {
        ZStack {
            SparkleBurstView()
            PostcardView(postcard: postcard)
                .rotation3DEffect(
                    .degrees(arrived ? 0 : 55),
                    axis: (x: 1, y: 0.15, z: 0)
                )
                .scaleEffect(arrived ? 1 : 0.55)
                .opacity(arrived ? 1 : 0)
                .offset(y: arrived ? 0 : -50)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.1)) {
                arrived = true
            }
        }
    }
}

/// A short amber shimmer — a few four-point sparkles, then gone. Celebration
/// with restraint: it rewards without turning the window into a carnival.
struct SparkleBurstView: View {
    private let start = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let age = context.date.timeIntervalSince(start)
                guard age < 1.8 else { return }
                for index in 0..<16 {
                    var random = NeighborhoodWorld.SeededRandom(state: UInt64(index) &* 3571 &+ 7)
                    let angle = Double.random(in: -Double.pi...Double.pi, using: &random)
                    let distance = Double.random(in: 60...170, using: &random)
                    let delay = Double.random(in: 0...0.3, using: &random)
                    let life = age - delay
                    guard life > 0, life < 1.2 else { continue }
                    let progress = life / 1.2
                    let eased = 1 - pow(1 - progress, 3)
                    let x = size.width / 2 + cos(angle) * distance * eased
                    let y = size.height / 2 + sin(angle) * distance * eased * 0.6
                    let fade = (1 - progress) * 0.9
                    let scale = 3.5 * (1 - progress * 0.5)

                    var sparkle = Path()
                    sparkle.move(to: CGPoint(x: x, y: y - scale))
                    sparkle.addQuadCurve(to: CGPoint(x: x + scale, y: y), control: CGPoint(x: x, y: y))
                    sparkle.addQuadCurve(to: CGPoint(x: x, y: y + scale), control: CGPoint(x: x, y: y))
                    sparkle.addQuadCurve(to: CGPoint(x: x - scale, y: y), control: CGPoint(x: x, y: y))
                    sparkle.addQuadCurve(to: CGPoint(x: x, y: y - scale), control: CGPoint(x: x, y: y))
                    canvas.fill(sparkle, with: .color(GardenAccent.amber.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Horizontal keepsake shelf shown beneath the garden.
struct PostcardAlbumView: View {
    let postcards: [Postcard]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(postcards.reversed()) { postcard in
                    PostcardView(postcard: postcard, compact: true)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
}

