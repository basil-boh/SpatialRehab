import AVFoundation
import SwiftUI
import UIKit

/// Owns the muted, endlessly looping player behind one moving portrait.
///
/// Playback lives in a reference type rather than being rebuilt in `body` because a
/// SwiftUI re-render must never restart or stack players — six of these run at once in
/// the family tree, and a stacked decoder per re-render would thermally throttle the
/// device within a minute.
@MainActor
final class MovingPortraitPlayer {
    let player = AVQueuePlayer()

    /// Must be retained for the lifetime of the loop: releasing the looper ends looping.
    private var looper: AVPlayerLooper?

    init() {
        player.isMuted = true
    }

    /// Idempotent — repeated calls keep the existing loop running rather than rebuilding it.
    func start(url: URL) {
        if looper == nil {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }
        player.play()
    }

    func pause() {
        player.pause()
    }
}

/// Bare video surface for an avatar.
///
/// `VideoPlayer` is unusable here: it brings playback controls and its own tap handling,
/// and this is a face in a tile, not a player. The circle is cut by the layer itself
/// instead of a SwiftUI `clipShape`, which does not reliably mask hosted layers.
private struct PortraitSurface: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PortraitSurfaceView {
        let view = PortraitSurfaceView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PortraitSurfaceView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class PortraitSurfaceView: UIView {
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        // The enclosing tile's Button owns the pinch; this surface must stay inert.
        isUserInteractionEnabled = false
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        // Square source in a square frame: half the side length is a true circle,
        // matching the avatar's ring exactly.
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

/// A relative's portrait, alive — a short clip looping silently inside the circular
/// avatar frame, the way the portraits move in Harry Potter.
///
/// Silent and seamless on purpose. The spoken greeting is a separate, longer video the
/// person reaches by pinching the tile: six faces mouthing words at once would unsettle
/// someone with dementia rather than comfort them.
///
/// `fallback` (the still photo or emoji) sits underneath so the tile is never blank while
/// the first frame decodes, and is all that shows under Reduce Motion.
struct MovingPortraitView<Fallback: View>: View {
    let url: URL
    @ViewBuilder var fallback: () -> Fallback

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var portrait = MovingPortraitPlayer()

    var body: some View {
        ZStack {
            fallback()

            if !reduceMotion {
                PortraitSurface(player: portrait.player)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            portrait.start(url: url)
        }
        .onDisappear {
            portrait.pause()
        }
        .onChange(of: scenePhase) { _, phase in
            // Six decoders must not keep running while the app is out of view.
            if phase == .active, !reduceMotion {
                portrait.start(url: url)
            } else {
                portrait.pause()
            }
        }
        .accessibilityHidden(true)
    }
}
