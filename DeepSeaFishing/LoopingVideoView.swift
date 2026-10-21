import SwiftUI
import AVFoundation

/// Silent, decorative looping video banner. The game supplies its own audio, so
/// the clip is muted, and it is hidden from VoiceOver. With Reduce Motion on,
/// it falls back to the still image so nothing moves.
struct LoopingVideoBanner: View {
    let resource: String
    let fallbackImage: String
    var height: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion || Bundle.main.url(forResource: resource, withExtension: "mp4") == nil {
                Image(fallbackImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LoopingPlayerView(resource: resource)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct LoopingPlayerView: UIViewRepresentable {
    let resource: String

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        if let url = Bundle.main.url(forResource: resource, withExtension: "mp4") {
            let player = AVQueuePlayer()
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            context.coordinator.player = player
            view.playerLayer.player = player
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.player?.play()
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        uiView.playerLayer.player = nil
    }
}
