import SwiftUI
import AppKit
import AVKit
import Combine

public struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }
    
    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

public struct GifTrimView: View {
    let fileURL: URL
    let onComplete: (Double, Double, Int, CGFloat) -> Void
    let onCancel: () -> Void
    
    // Players: main player and dedicated loop player
    @State private var mainPlayer: AVPlayer?
    @State private var loopPlayer: AVPlayer?
    
    @State private var totalDuration: Double = 10.0
    @State private var startTime: Double = 0.0
    @State private var endTime: Double = 4.0
    @State private var currentTime: Double = 0.0
    
    @State private var selectedFps: Int = 12
    @State private var selectedWidth: CGFloat = 640
    
    // Looping & Playback state
    @State private var isSeeking: Bool = false
    @State private var loopTimer: Timer?
    @State private var timeObserverToken: Any?
    
    // Filmstrip thumbnails
    @State private var filmstripThumbnails: [NSImage] = []
    
    // Drag gestures anchors
    @State private var dragInitialStartTime: Double? = nil
    @State private var dragInitialEndTime: Double? = nil
    @State private var dragInitialRange: (start: Double, end: Double)? = nil
    
    public init(
        fileURL: URL,
        onComplete: @escaping (Double, Double, Int, CGFloat) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.fileURL = fileURL
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // 1. Header with Badges
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GIF 구간 편집 및 미리보기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                let duration = max(0.2, endTime - startTime)
                let estFrames = Int(duration * Double(selectedFps))
                
                HStack(spacing: 8) {
                    Text(String(format: "구간: %.1f초 ~ %.1f초 (%.1f초)", startTime, endTime, duration))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    
                    Text("\(estFrames)프레임")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // 2. Dual Previews: [Original Video] and [Real-time Looping GIF Preview]
            HStack(spacing: 16) {
                // Left: Original Video Scrubber View
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("원본 영상 탐색", systemImage: "film.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(currentTime))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack {
                        if let player = mainPlayer {
                            NativePlayerView(player: player)
                                .frame(height: 200)
                                .background(Color.black)
                                .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 200)
                                .cornerRadius(8)
                                .overlay(ProgressView())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right: Real-time Looping GIF Preview
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("GIF 무한 루프 미리보기", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("실시간 재생 중")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ZStack {
                        if let lPlayer = loopPlayer {
                            NativePlayerView(player: lPlayer)
                                .frame(height: 200)
                                .background(Color.black)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)
                                )
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 200)
                                .cornerRadius(8)
                                .overlay(ProgressView())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            
            // 3. iPhone Photos Style Filmstrip Scrubber Track
            VStack(spacing: 6) {
                HStack {
                    Text("00:00")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("양쪽 노란색 핸들을 드래그하거나 가운데 영역을 밀어 구간을 조정하세요")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                    Spacer()
                    Text(formatTime(totalDuration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                
                // Interactive Range Slider Track
                GeometryReader { geo in
                    let trackW = geo.size.width
                    let trackH: CGFloat = 50
                    let durationSafe = max(0.1, totalDuration)
                    
                    let startRatio = max(0.0, min(startTime / durationSafe, 1.0))
                    let endRatio = max(0.0, min(endTime / durationSafe, 1.0))
                    
                    let startX = startRatio * trackW
                    let endX = endRatio * trackW
                    let selWidth = max(28, endX - startX)
                    
                    let playheadRatio = max(0.0, min(currentTime / durationSafe, 1.0))
                    let playheadX = playheadRatio * trackW
                    
                    ZStack(alignment: .topLeading) {
                        // 1. Base Track Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                            .frame(width: trackW, height: trackH)
                        
                        // 2. Filmstrip Thumbnails
                        if !filmstripThumbnails.isEmpty {
                            HStack(spacing: 0) {
                                ForEach(0..<filmstripThumbnails.count, id: \.self) { idx in
                                    Image(nsImage: filmstripThumbnails[idx])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: trackH)
                                        .clipped()
                                }
                            }
                            .frame(width: trackW, height: trackH)
                            .opacity(0.55)
                        }
                        
                        // 3. Left Unselected Dimming Mask (Inside bounds strictly)
                        if startX > 0 {
                            let leftDimW = max(0, min(startX, trackW))
                            Rectangle()
                                .fill(Color.black.opacity(0.72))
                                .frame(width: leftDimW, height: trackH)
                                .position(x: leftDimW / 2, y: trackH / 2)
                        }
                        
                        // 4. Right Unselected Dimming Mask (Inside bounds strictly)
                        if endX < trackW {
                            let rightDimW = max(0, trackW - endX)
                            Rectangle()
                                .fill(Color.black.opacity(0.72))
                                .frame(width: rightDimW, height: trackH)
                                .position(x: endX + rightDimW / 2, y: trackH / 2)
                        }
                        
                        // 5. iOS Style Blue Trim Box
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .background(Color.accentColor.opacity(0.15))
                            .frame(width: selWidth, height: trackH)
                            .position(x: startX + selWidth / 2, y: trackH / 2)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        if dragInitialRange == nil {
                                            dragInitialRange = (start: startTime, end: endTime)
                                        }
                                        guard let initial = dragInitialRange else { return }
                                        let windowDuration = initial.end - initial.start
                                        let deltaSec = Double(value.translation.width / trackW) * totalDuration
                                        
                                        var newStart = initial.start + deltaSec
                                        var newEnd = initial.end + deltaSec
                                        
                                        if newStart < 0 {
                                            newStart = 0
                                            newEnd = windowDuration
                                        } else if newEnd > totalDuration {
                                            newEnd = totalDuration
                                            newStart = totalDuration - windowDuration
                                        }
                                        
                                        self.startTime = newStart
                                        self.endTime = newEnd
                                        updateRangePlayback()
                                    }
                                    .onEnded { _ in
                                        dragInitialRange = nil
                                    }
                            )
                        
                        // 6. Left Handle
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: trackH)
                            .overlay(
                                Image(systemName: "chevron.compact.left")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .position(x: startX + 7, y: trackH / 2)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        if dragInitialStartTime == nil {
                                            dragInitialStartTime = startTime
                                        }
                                        let initial = dragInitialStartTime!
                                        let deltaSec = Double(value.translation.width / trackW) * totalDuration
                                        let newSec = initial + deltaSec
                                        self.startTime = max(0.0, min(newSec, endTime - 0.3))
                                        updateRangePlayback()
                                    }
                                    .onEnded { _ in
                                        dragInitialStartTime = nil
                                    }
                            )
                        
                        // 7. Right Handle
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: trackH)
                            .overlay(
                                Image(systemName: "chevron.compact.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .position(x: endX - 7, y: trackH / 2)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        if dragInitialEndTime == nil {
                                            dragInitialEndTime = endTime
                                        }
                                        let initial = dragInitialEndTime!
                                        let deltaSec = Double(value.translation.width / trackW) * totalDuration
                                        let newSec = initial + deltaSec
                                        self.endTime = min(totalDuration, max(newSec, startTime + 0.3))
                                        updateRangePlayback()
                                    }
                                    .onEnded { _ in
                                        dragInitialEndTime = nil
                                    }
                            )
                        
                        // 8. Current Playhead Needle (White marker)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: trackH + 6)
                            .position(x: min(max(playheadX, 1), trackW - 1), y: trackH / 2)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 50)
                .padding(.horizontal, 20)
            }
            
            // 4. Output Quality & FPS Pickers (Spacious, balanced container card)
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("프레임 레이트 (FPS)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("프레임 레이트", selection: $selectedFps) {
                        Text("10 FPS (경량)").tag(10)
                        Text("12 FPS (표준)").tag(12)
                        Text("15 FPS (부드러움)").tag(15)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("해상도 너비")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("해상도 너비", selection: $selectedWidth) {
                        Text("480px").tag(CGFloat(480))
                        Text("640px (표준)").tag(CGFloat(640))
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            
            Divider()
                .opacity(0.3)
            
            // 5. Action Buttons
            HStack {
                Button("취소") {
                    cleanup()
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("GIF 생성 및 저장") {
                    cleanup()
                    onComplete(startTime, endTime, selectedFps, selectedWidth)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 680, height: 540)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            setupPlayers()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Playback & Looping Control
    
    private func setupPlayers() {
        let mPlayer = AVPlayer(url: fileURL)
        mPlayer.isMuted = true
        let lPlayer = AVPlayer(url: fileURL)
        lPlayer.isMuted = true
        
        self.mainPlayer = mPlayer
        self.loopPlayer = lPlayer
        
        Task {
            let asset = AVAsset(url: fileURL)
            if let durationTime = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(durationTime)
                if seconds > 0 {
                    await MainActor.run {
                        self.totalDuration = seconds
                        self.startTime = 0.0
                        self.endTime = min(seconds, 4.0) // Default 4 seconds for GIF
                        
                        startLoopTimer()
                        setupTimeObserver()
                        
                        mPlayer.play()
                        lPlayer.play()
                    }
                    
                    // Asynchronously generate filmstrip thumbnails
                    await generateFilmstripThumbnails(asset: asset, duration: seconds)
                }
            }
        }
    }
    
    private func generateFilmstripThumbnails(asset: AVAsset, duration: Double) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 140, height: 90)
        
        let count = 10
        var loadedImages: [NSImage] = []
        for i in 0..<count {
            let sec = (Double(i) / Double(count)) * duration
            let cmTime = CMTime(seconds: sec, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                loadedImages.append(NSImage(cgImage: cgImage, size: CGSize(width: 70, height: 45)))
            }
        }
        
        if !loadedImages.isEmpty {
            await MainActor.run {
                self.filmstripThumbnails = loadedImages
            }
        }
    }
    
    private func setupTimeObserver() {
        guard let player = mainPlayer else { return }
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let sec = CMTimeGetSeconds(time)
            self.currentTime = sec
            if sec >= self.totalDuration {
                player.seek(to: .zero)
                player.play()
            }
        }
    }
    
    private func startLoopTimer() {
        loopTimer?.invalidate()
        // Seamless loop without infinite seek recursion
        loopTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak loopPlayer] _ in
            guard let player = loopPlayer, !self.isSeeking else { return }
            let sec = CMTimeGetSeconds(player.currentTime())
            if sec >= self.endTime {
                self.isSeeking = true
                let seekTarget = CMTime(seconds: self.startTime, preferredTimescale: 600)
                player.seek(to: seekTarget, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    self.isSeeking = false
                    player.play()
                }
            }
        }
    }
    
    private func updateRangePlayback() {
        guard let lPlayer = loopPlayer, !isSeeking else { return }
        self.isSeeking = true
        let seekTarget = CMTime(seconds: startTime, preferredTimescale: 600)
        lPlayer.seek(to: seekTarget, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            self.isSeeking = false
            lPlayer.play()
        }
    }
    
    private func cleanup() {
        loopTimer?.invalidate()
        loopTimer = nil
        
        if let token = timeObserverToken, let player = mainPlayer {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        mainPlayer?.pause()
        loopPlayer?.pause()
        mainPlayer?.replaceCurrentItem(with: nil)
        loopPlayer?.replaceCurrentItem(with: nil)
        mainPlayer = nil
        loopPlayer = nil
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1.0)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, millis)
    }
}

final class GifTrimWindowDelegate: NSObject, NSWindowDelegate {
    var onTerminate: (() -> Void)?
    
    func windowWillClose(_ notification: Notification) {
        onTerminate?()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            win.close()
        }
    }
}

public final class GifTrimWindowController {
    public static let shared = GifTrimWindowController()
    private var window: NSWindow?
    private var windowDelegate: GifTrimWindowDelegate?
    
    public func show(for url: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "GIF 변환 구간 설정"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        
        let delegate = GifTrimWindowDelegate()
        window.delegate = delegate
        self.windowDelegate = delegate
        
        let trimView = GifTrimView(
            fileURL: url,
            onComplete: { [weak window, weak self] start, end, fps, width in
                window?.close()
                self?.window = nil
                self?.windowDelegate = nil
                Task.detached {
                    await MainActor.run {
                        ProgressManager.shared.startTask(title: "GIF 생성 중", detail: String(format: "%.1f초~%.1f초", start, end))
                    }
                    do {
                        let result = try await MediaWorker.videoToGif(
                            file: url,
                            startTime: start,
                            endTime: end,
                            fps: fps,
                            maxWidth: width
                        ) { progress in
                            Task { @MainActor in
                                ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 렌더링 중")
                            }
                        }
                        await MainActor.run {
                            ProgressManager.shared.completeTask(title: "GIF 생성 완료", message: result.lastPathComponent)
                        }
                        NotificationManager.shared.send(
                            title: "GIF 생성 완료",
                            body: result.lastPathComponent,
                            fileURL: result
                        )
                    } catch {
                        await MainActor.run {
                            ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                        }
                    }
                }
            },
            onCancel: { [weak window, weak self] in
                window?.close()
                self?.window = nil
                self?.windowDelegate = nil
            }
        )
        
        delegate.onTerminate = { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        
        window.contentView = NSHostingView(rootView: trimView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
