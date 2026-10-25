import SwiftUI
import AppKit

public struct ImageOptimizeView: View {
    let files: [URL]
    let onComplete: (ImageOptimizationSettings) -> Void
    let onCancel: () -> Void
    
    // Original image stats from the first file
    @State private var originalWidth: Int = 0
    @State private var originalHeight: Int = 0
    @State private var originalFileSizeStr: String = ""
    @State private var originalFormat: String = ""
    
    // User configuration states
    @State private var scalePercentage: Double = 0.5 // Default 50% scale
    @State private var customMaxWidth: CGFloat? = nil
    @State private var quality: Double = 0.75 // Default 75% quality
    @State private var formatMode: OptimizationFormatMode = .keepOriginal
    
    public init(
        files: [URL],
        onComplete: @escaping (ImageOptimizationSettings) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.files = files
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("이미지 용량 최적화 (다이어트)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if files.count == 1, let first = files.first {
                        Text(first.lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(files.count)개 이미지 일괄 최적화")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Original file status badge
                if originalWidth > 0 {
                    HStack(spacing: 8) {
                        Text("\(originalWidth) × \(originalHeight) px")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        
                        Text(originalFileSizeStr)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Section 1: Resolution Scale
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("해상도 축소 비율", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if originalWidth > 0 {
                        let targetW = customMaxWidth != nil ? Int(min(customMaxWidth!, CGFloat(originalWidth))) : Int(Double(originalWidth) * scalePercentage)
                        let targetH = customMaxWidth != nil ? Int(CGFloat(originalHeight) * (CGFloat(targetW) / CGFloat(originalWidth))) : Int(Double(originalHeight) * scalePercentage)
                        Text("➔ 변경 후: \(targetW) × \(targetH) px")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                }
                
                HStack(spacing: 8) {
                    scaleButton(label: "100% (원본)", value: 1.0)
                    scaleButton(label: "75% (고품질)", value: 0.75)
                    scaleButton(label: "50% (추천)", value: 0.5)
                    scaleButton(label: "25% (초경량)", value: 0.25)
                }
                
                HStack(spacing: 8) {
                    widthPresetButton(label: "FHD (1920px)", width: 1920)
                    widthPresetButton(label: "HD (1280px)", width: 1280)
                    widthPresetButton(label: "웹/블로그 (800px)", width: 800)
                }
            }
            .padding(.horizontal, 20)
            
            // Section 2: Quality & Compression
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("압축 품질", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(quality * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Picker("압축 품질", selection: $quality) {
                    Text("고화질 (90%)").tag(0.90)
                    Text("표준 균형 (75% 추천)").tag(0.75)
                    Text("최대 압축 (60%)").tag(0.60)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 20)
            
            // Section 3: Target Format
            VStack(alignment: .leading, spacing: 8) {
                Label("저장 포맷", systemImage: "doc.badge.gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Picker("저장 포맷", selection: $formatMode) {
                    ForEach(OptimizationFormatMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 20)
            
            // Expected Reduction Preview Card
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("예상 절감 효과: 약 \(estimateReduction())% 용량 감소")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("해상도 리사이징과 지능형 압축을 적용하여 화질 손실 없이 용량을 극대화하여 줄입니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("취소") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("최적화 실행") {
                    let settings = ImageOptimizationSettings(
                        scalePercentage: scalePercentage,
                        customMaxWidth: customMaxWidth,
                        quality: quality,
                        formatMode: formatMode
                    )
                    onComplete(settings)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 520, height: 480)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            inspectSourceFile()
        }
    }
    
    // MARK: - UI Helpers
    
    private func scaleButton(label: String, value: Double) -> some View {
        let isSelected = customMaxWidth == nil && scalePercentage == value
        return Button(action: {
            customMaxWidth = nil
            scalePercentage = value
        }) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func widthPresetButton(label: String, width: CGFloat) -> some View {
        let isSelected = customMaxWidth == width
        return Button(action: {
            customMaxWidth = width
        }) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func estimateReduction() -> Int {
        var base: Double = 0.0
        if let maxW = customMaxWidth, originalWidth > 0 {
            let ratio = Double(min(maxW, CGFloat(originalWidth))) / Double(originalWidth)
            base = 1.0 - (ratio * ratio)
        } else {
            base = 1.0 - (scalePercentage * scalePercentage)
        }
        
        let qualityFactor = (1.0 - quality) * 0.5
        let total = min(0.95, base + qualityFactor + (formatMode == .convertToJpg ? 0.2 : 0.0))
        return max(15, Int(total * 100))
    }
    
    private func inspectSourceFile() {
        guard let first = files.first else { return }
        originalFormat = first.pathExtension.uppercased()
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: first.path),
           let size = attr[.size] as? Int64 {
            let mb = Double(size) / (1024 * 1024)
            if mb >= 1.0 {
                originalFileSizeStr = String(format: "%.1f MB", mb)
            } else {
                let kb = Double(size) / 1024
                originalFileSizeStr = String(format: "%.0f KB", kb)
            }
        }
        
        if let source = CGImageSourceCreateWithURL(first as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
           let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
            originalWidth = Int(w)
            originalHeight = Int(h)
        }
    }
}

public final class ImageOptimizeWindowController {
    public static let shared = ImageOptimizeWindowController()
    private var window: NSWindow?
    
    public func show(for files: [URL]) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "이미지 용량 최적화 설정"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        
        let optimizeView = ImageOptimizeView(
            files: files,
            onComplete: { [weak window] settings in
                window?.close()
                Task.detached {
                    await MainActor.run {
                        ProgressManager.shared.startTask(title: "이미지 용량 최적화 중", detail: "\(files.count)개 파일")
                    }
                    do {
                        let results = try await ImageOptimizationWorker.optimizeImagesWithSettings(
                            files: files,
                            settings: settings
                        ) { progress in
                            Task { @MainActor in
                                ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 압축 처리 중")
                            }
                        }
                        await MainActor.run {
                            ProgressManager.shared.completeTask(title: "최적화 완료", message: "\(results.count)개 파일 저장됨")
                        }
                        NotificationManager.shared.send(
                            title: "용량 최적화 완료",
                            body: "\(results.count)개의 파일이 다이어트 완료되었습니다.",
                            fileURL: results.first
                        )
                    } catch {
                        await MainActor.run {
                            ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                        }
                    }
                }
            },
            onCancel: { [weak window] in
                window?.close()
            }
        )
        
        window.contentView = NSHostingView(rootView: optimizeView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
