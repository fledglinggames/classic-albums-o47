import SwiftUI
import Photos
import AVFoundation

struct PhotoPageContent: View {
    let asset: PHAsset
    var isActive: Bool
    @Binding var zoomScale: CGFloat
    var onSingleTap: () -> Void = {}

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var isPlayingLive = false
    @State private var player: AVPlayer?
    @State private var isPlayingVideo = false
    @State private var currentTime: Double = 0
    @State private var videoDuration: Double = 0
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    @AppStorage("pixelArtCrispThreshold") private var pixelArtCrispThreshold: Int = 256
    @AppStorage("fullResIndicatorStyle") private var fullResIndicatorStyle: String = "off"

    private var isCrisp: Bool {
        pixelArtCrispThreshold > 0 &&
            max(asset.pixelWidth, asset.pixelHeight) <= pixelArtCrispThreshold
    }

    private var isFullResolution: Bool {
        guard let image, let cg = image.cgImage else { return false }
        return max(cg.width, cg.height) >= max(asset.pixelWidth, asset.pixelHeight)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.systemBackground)
                if let livePhoto {
                    livePhotoView(livePhoto)
                } else if let player {
                    videoView(player)
                } else if let image {
                    imageView(image)
                } else {
                    ProgressView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                toggleZoom(in: proxy.size)
            }
            .onTapGesture(count: 1) {
                if player != nil {
                    toggleVideoPlayback()
                } else {
                    onSingleTap()
                }
            }
            .overlay(alignment: .bottom) {
                if player != nil {
                    videoScrubber
                        .padding(.bottom, 8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isFullResolution && fullResIndicatorStyle == "lightGraySquare" {
                    Rectangle()
                        .fill(Color(white: 0.75))
                        .frame(width: 8, height: 8)
                        .padding(.top, 58)
                        .padding(.trailing, 14)
                }
            }
        }
        .ignoresSafeArea()
        .task(id: asset.localIdentifier) {
            await loadInitialMedia()
        }
        .task(id: FullResKey(assetID: asset.localIdentifier, wantsFullRes: isActive && zoomScale > 1.0)) {
            guard isActive, zoomScale > 1.0, !isFullResolution, !isCrisp else { return }
            await loadFullResolutionImage()
        }
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                player?.pause()
                isPlayingVideo = false
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private struct FullResKey: Hashable {
        let assetID: String
        let wantsFullRes: Bool
    }

    @ViewBuilder
    private func livePhotoView(_ livePhoto: PHLivePhoto) -> some View {
        let base = LivePhotoViewer(livePhoto: livePhoto, isPlaying: $isPlayingLive)
            .aspectRatio(CGSize(width: asset.pixelWidth, height: asset.pixelHeight), contentMode: .fit)
            .scaleEffect(zoomScale)
            .offset(offset)
            .gesture(magnification)
            .overlay(alignment: .topLeading) {
                if !isPlayingLive {
                    liveBadge
                        .padding(12)
                }
            }

        if zoomScale > 1.0 {
            base.simultaneousGesture(pan)
        } else {
            base
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "livephoto")
                .font(.system(size: 14, weight: .semibold))
            Text("LIVE")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.35), in: Capsule())
    }

    @ViewBuilder
    private func videoView(_ player: AVPlayer) -> some View {
        let base = VideoPlayerView(player: player)
            .aspectRatio(CGSize(width: asset.pixelWidth, height: asset.pixelHeight), contentMode: .fit)
            .scaleEffect(zoomScale)
            .offset(offset)
            .gesture(magnification)
            .overlay {
                if !isPlayingVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(radius: 4)
                        .allowsHitTesting(false)
                }
            }

        if zoomScale > 1.0 {
            base.simultaneousGesture(pan)
        } else {
            base
        }
    }

    private var videoScrubber: some View {
        HStack(spacing: 10) {
            Button {
                toggleVideoPlayback()
            } label: {
                Image(systemName: isPlayingVideo ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
            }
            Text(timeString(currentTime))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white)
            Slider(
                value: Binding(
                    get: { min(currentTime, max(videoDuration, 0.001)) },
                    set: { seek(to: $0) }
                ),
                in: 0...max(videoDuration, 0.001)
            )
            .tint(.white)
            Text(timeString(videoDuration))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.35), in: Capsule())
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func imageView(_ image: UIImage) -> some View {
        let base = Group {
            if let frames = image.images, frames.count > 1 {
                AnimatedImageView(image: image, crisp: isCrisp)
                    .aspectRatio(image.size, contentMode: .fit)
            } else {
                Image(uiImage: image)
                    .interpolation(isCrisp ? .none : .high)
                    .antialiased(!isCrisp)
                    .resizable()
                    .scaledToFit()
            }
        }
        .scaleEffect(zoomScale)
        .offset(offset)
        .gesture(magnification)

        if zoomScale > 1.0 {
            base.simultaneousGesture(pan)
        } else {
            base
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = max(1.0, min(6.0, baseScale * value))
            }
            .onEnded { _ in
                baseScale = zoomScale
                if zoomScale <= 1.0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = .zero
                        baseOffset = .zero
                    }
                }
            }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseOffset = offset
            }
    }

    private func toggleZoom(in size: CGSize) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if zoomScale > 1.0 {
                zoomScale = 1.0
                baseScale = 1.0
                offset = .zero
                baseOffset = .zero
            } else {
                zoomScale = 2.0
                baseScale = 2.0
            }
        }
    }

    private func toggleVideoPlayback() {
        guard let player else { return }
        if isPlayingVideo {
            player.pause()
            isPlayingVideo = false
        } else {
            if videoDuration > 0, currentTime >= videoDuration - 0.05 {
                player.seek(to: .zero)
                currentTime = 0
            }
            player.play()
            isPlayingVideo = true
        }
    }

    private func seek(to time: Double) {
        guard let player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func cleanupPlayer() {
        if let player, let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        player?.pause()
        player = nil
        timeObserver = nil
        endObserver = nil
        isPlayingVideo = false
        currentTime = 0
        videoDuration = 0
    }

    private func loadInitialMedia() async {
        switch asset.playbackStyle {
        case .imageAnimated:
            await loadAnimatedImage()
        case .livePhoto:
            await loadLivePhoto()
        case .video, .videoLooping:
            await loadVideo()
        default:
            await loadStillImage()
        }
    }

    private func loadStillImage() async {
        if isCrisp {
            await loadCrispStillImage()
        } else {
            await loadDisplayStillImage()
        }
    }

    private func loadDisplayStillImage() async {
        for await result in ImageService.shared.requestDisplayImage(for: asset) {
            if Task.isCancelled { return }
            self.image = result
        }
    }

    private func loadCrispStillImage() async {
        for await data in ImageService.shared.requestOriginalData(for: asset) {
            if Task.isCancelled { return }
            guard let img = UIImage(data: data) else { continue }
            if Task.isCancelled { return }
            if let normalized = Self.normalizedToSRGB(img) {
                self.image = normalized
            } else {
                self.image = img
            }
        }
    }

    private func loadFullResolutionImage() async {
        for await result in ImageService.shared.requestFullResolutionImage(for: asset) {
            if Task.isCancelled { return }
            self.image = result
        }
    }

    private func loadLivePhoto() async {
        var got: PHLivePhoto?
        for await result in ImageService.shared.requestLivePhoto(for: asset) {
            if Task.isCancelled { return }
            got = result
            self.livePhoto = result
        }
        if Task.isCancelled { return }
        if got == nil {
            await loadStillImage()
        }
    }

    private func loadAnimatedImage() async {
        var gotData: Data?
        for await data in ImageService.shared.requestOriginalData(for: asset) {
            if Task.isCancelled { return }
            gotData = data
        }
        guard let data = gotData else {
            await loadStillImage()
            return
        }
        let decoded = await Task.detached(priority: .userInitiated) {
            GIFDecoder.decode(data: data)
        }.value
        if Task.isCancelled { return }
        if let decoded {
            self.image = decoded
        } else {
            await loadStillImage()
        }
    }

    private func loadVideo() async {
        var gotItem: AVPlayerItem?
        for await item in ImageService.shared.requestPlayerItem(for: asset) {
            if Task.isCancelled { return }
            gotItem = item
        }
        guard let item = gotItem else { return }

        let newPlayer = AVPlayer(playerItem: item)
        self.player = newPlayer

        let durationSec = item.asset.duration.seconds
        if durationSec.isFinite, durationSec > 0 {
            self.videoDuration = durationSec
        }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let observer = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            MainActor.assumeIsolated {
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if self.videoDuration <= 0,
                   let d = newPlayer.currentItem?.duration.seconds,
                   d.isFinite, d > 0 {
                    self.videoDuration = d
                }
            }
        }
        self.timeObserver = observer

        let end = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                newPlayer.seek(to: .zero)
                newPlayer.pause()
                self.isPlayingVideo = false
                self.currentTime = 0
            }
        }
        self.endObserver = end
    }

    private static func normalizedToSRGB(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = cg.width
        let height = cg.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = context.makeImage() else { return nil }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }
}
