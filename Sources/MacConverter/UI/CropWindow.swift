import SwiftUI
import AppKit
import AVFoundation

public enum CropAspectRatio: String, CaseIterable, Identifiable {
    case free = "자유"
    case square = "1:1"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case threeTwo = "3:2"
    
    public var id: String { rawValue }
    
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1.0
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .threeTwo: return 3.0 / 2.0
        }
    }
}

public struct CropView: View {
    let fileURL: URL
    let onComplete: (URL?) -> Void
    
    @State private var originalImage: NSImage?
    @State private var cgImage: CGImage?
    @State private var pixelSize: CGSize = .zero
    
    // Geometry & Layout states
    @State private var containerSize: CGSize = .zero
    @State private var imageRenderRect: CGRect = .zero
    @State private var cropRect: CGRect = .zero
    
    @State private var selectedAspectRatio: CropAspectRatio = .free
    
    // Pixel Input States
    @State private var inputWidthText: String = ""
    @State private var inputHeightText: String = ""
    
    // Drag gestures anchor states
    @State private var initialCropRectOnDrag: CGRect? = nil
    
    public init(fileURL: URL, onComplete: @escaping (URL?) -> Void) {
        self.fileURL = fileURL
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("이미지 크롭 (Crop)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Real-time editable crop resolution controls
                if pixelSize.width > 0, imageRenderRect.width > 0 {
                    HStack(spacing: 6) {
                        Label("자르기 크기:", systemImage: "crop")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        NumericPixelTextField(text: $inputWidthText) {
                            applyTypedPixelDimensions()
                        }
                        .frame(width: 48, height: 18)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                        
                        Text("×")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        NumericPixelTextField(text: $inputHeightText) {
                            applyTypedPixelDimensions()
                        }
                        .frame(width: 48, height: 18)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                        
                        Text("px")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("(원본: \(Int(pixelSize.width))×\(Int(pixelSize.height)))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Aspect Ratio Toolbar
            HStack(spacing: 8) {
                Text("비율:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                ForEach(CropAspectRatio.allCases) { ratio in
                    Button(action: {
                        selectedAspectRatio = ratio
                        applyAspectRatio(ratio)
                    }) {
                        Text(ratio.rawValue)
                            .font(.system(size: 11, weight: selectedAspectRatio == ratio ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedAspectRatio == ratio ? Color.accentColor : Color.primary.opacity(0.06))
                            .foregroundColor(selectedAspectRatio == ratio ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: resetToFullImage) {
                    Label("전체 선택", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Image Preview & Interactive Crop Canvas
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Container background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.45))
                    
                    if let image = originalImage {
                        // 1. Rendered Image placed exactly at imageRenderRect
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageRenderRect.width, height: imageRenderRect.height)
                            .position(x: imageRenderRect.midX, y: imageRenderRect.midY)
                        
                        // 2. Dark Dimming Masks (Outside cropRect)
                        dimmingMasks(containerSize: geo.size)
                        
                        // 3. Crop Box Border & Rule-of-Thirds Grid
                        cropBoxView
                        
                        // 4. Interactive Corner & Edge Drag Handles
                        dragHandlesView
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    setupLayout(container: geo.size)
                }
                .onChange(of: geo.size) {
                    setupLayout(container: geo.size)
                }
            }
            .frame(height: 380)
            .padding(.horizontal, 20)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("취소") {
                    onComplete(nil)
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("자르기 및 저장") {
                    performCrop()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 620, height: 530)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            loadImageData()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func dimmingMasks(containerSize: CGSize) -> some View {
        let maskColor = Color.black.opacity(0.55)
        
        // Top dimming
        if cropRect.minY > 0 {
            Rectangle()
                .fill(maskColor)
                .frame(width: containerSize.width, height: max(0, cropRect.minY))
                .position(x: containerSize.width / 2, y: max(0, cropRect.minY) / 2)
        }
        
        // Bottom dimming
        if cropRect.maxY < containerSize.height {
            let h = max(0, containerSize.height - cropRect.maxY)
            Rectangle()
                .fill(maskColor)
                .frame(width: containerSize.width, height: h)
                .position(x: containerSize.width / 2, y: cropRect.maxY + h / 2)
        }
        
        // Left dimming
        if cropRect.minX > 0 {
            Rectangle()
                .fill(maskColor)
                .frame(width: max(0, cropRect.minX), height: cropRect.height)
                .position(x: max(0, cropRect.minX) / 2, y: cropRect.midY)
        }
        
        // Right dimming
        if cropRect.maxX < containerSize.width {
            let w = max(0, containerSize.width - cropRect.maxX)
            Rectangle()
                .fill(maskColor)
                .frame(width: w, height: cropRect.height)
                .position(x: cropRect.maxX + w / 2, y: cropRect.midY)
        }
    }
    
    private var cropBoxView: some View {
        ZStack {
            // Rule of thirds grid lines
            VStack {
                Spacer()
                Divider().background(Color.white.opacity(0.35))
                Spacer()
                Divider().background(Color.white.opacity(0.35))
                Spacer()
            }
            
            HStack {
                Spacer()
                Divider().background(Color.white.opacity(0.35))
                Spacer()
                Divider().background(Color.white.opacity(0.35))
                Spacer()
            }
            
            // Outer glowing border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 2)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
        .frame(width: max(30, cropRect.width), height: max(30, cropRect.height))
        .position(x: cropRect.midX, y: cropRect.midY)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if initialCropRectOnDrag == nil {
                        initialCropRectOnDrag = cropRect
                    }
                    guard let initial = initialCropRectOnDrag else { return }
                    
                    var newX = initial.origin.x + value.translation.width
                    var newY = initial.origin.y + value.translation.height
                    
                    // Clamp inside imageRenderRect
                    newX = min(max(newX, imageRenderRect.minX), imageRenderRect.maxX - initial.width)
                    newY = min(max(newY, imageRenderRect.minY), imageRenderRect.maxY - initial.height)
                    
                    cropRect.origin = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in
                    initialCropRectOnDrag = nil
                }
        )
    }
    
    private var dragHandlesView: some View {
        Group {
            // Top-Left Handle
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.minY)) { dx, dy in
                resizeCrop(deltaMinX: dx, deltaMinY: dy, deltaMaxX: 0, deltaMaxY: 0)
            }
            // Top-Right Handle
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.minY)) { dx, dy in
                resizeCrop(deltaMinX: 0, deltaMinY: dy, deltaMaxX: dx, deltaMaxY: 0)
            }
            // Bottom-Left Handle
            cornerHandle(at: CGPoint(x: cropRect.minX, y: cropRect.maxY)) { dx, dy in
                resizeCrop(deltaMinX: dx, deltaMinY: 0, deltaMaxX: 0, deltaMaxY: dy)
            }
            // Bottom-Right Handle
            cornerHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.maxY)) { dx, dy in
                resizeCrop(deltaMinX: 0, deltaMinY: 0, deltaMaxX: dx, deltaMaxY: dy)
            }
        }
    }
    
    private func cornerHandle(at point: CGPoint, onDrag: @escaping (CGFloat, CGFloat) -> Void) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 3)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if initialCropRectOnDrag == nil {
                            initialCropRectOnDrag = cropRect
                        }
                        onDrag(value.translation.width, value.translation.height)
                    }
                    .onEnded { _ in
                        initialCropRectOnDrag = nil
                    }
            )
    }
    
    // MARK: - Logic & Calculations
    
    private func loadImageData() {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cgImg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return
        }
        self.cgImage = cgImg
        self.pixelSize = CGSize(width: cgImg.width, height: cgImg.height)
        self.originalImage = NSImage(cgImage: cgImg, size: CGSize(width: cgImg.width, height: cgImg.height))
    }
    
    private func setupLayout(container: CGSize) {
        guard container.width > 0, container.height > 0, pixelSize.width > 0, pixelSize.height > 0 else {
            return
        }
        self.containerSize = container
        
        let imgAspect = pixelSize.width / pixelSize.height
        let viewAspect = container.width / container.height
        
        var renderW: CGFloat = 0
        var renderH: CGFloat = 0
        var originX: CGFloat = 0
        var originY: CGFloat = 0
        
        if imgAspect > viewAspect {
            renderW = container.width
            renderH = container.width / imgAspect
            originX = 0
            originY = (container.height - renderH) / 2
        } else {
            renderH = container.height
            renderW = container.height * imgAspect
            originX = (container.width - renderW) / 2
            originY = 0
        }
        
        self.imageRenderRect = CGRect(x: originX, y: originY, width: renderW, height: renderH)
        
        // Initialize default crop rect to 85% center of image
        let insetX = renderW * 0.075
        let insetY = renderH * 0.075
        self.cropRect = CGRect(
            x: originX + insetX,
            y: originY + insetY,
            width: renderW * 0.85,
            height: renderH * 0.85
        )
        syncTextWithCropRect()
    }
    
    private func resetToFullImage() {
        selectedAspectRatio = .free
        cropRect = imageRenderRect
        syncTextWithCropRect()
    }
    
    private func applyAspectRatio(_ ratio: CropAspectRatio) {
        guard let r = ratio.ratio, imageRenderRect.width > 0, imageRenderRect.height > 0 else { return }
        
        var targetW = cropRect.width
        var targetH = targetW / r
        
        if targetH > imageRenderRect.height {
            targetH = imageRenderRect.height * 0.9
            targetW = targetH * r
        }
        if targetW > imageRenderRect.width {
            targetW = imageRenderRect.width * 0.9
            targetH = targetW / r
        }
        
        let newX = imageRenderRect.midX - targetW / 2
        let newY = imageRenderRect.midY - targetH / 2
        cropRect = CGRect(x: newX, y: newY, width: targetW, height: targetH)
        syncTextWithCropRect()
    }
    
    private func resizeCrop(deltaMinX: CGFloat, deltaMinY: CGFloat, deltaMaxX: CGFloat, deltaMaxY: CGFloat) {
        guard let initial = initialCropRectOnDrag else { return }
        
        var newMinX = initial.minX + deltaMinX
        var newMinY = initial.minY + deltaMinY
        var newMaxX = initial.maxX + deltaMaxX
        var newMaxY = initial.maxY + deltaMaxY
        
        // Clamp to imageRenderRect
        newMinX = max(imageRenderRect.minX, min(newMinX, initial.maxX - 30))
        newMinY = max(imageRenderRect.minY, min(newMinY, initial.maxY - 30))
        newMaxX = min(imageRenderRect.maxX, max(newMaxX, initial.minX + 30))
        newMaxY = min(imageRenderRect.maxY, max(newMaxY, initial.minY + 30))
        
        if let ratio = selectedAspectRatio.ratio {
            // Preserve aspect ratio
            let currentW = newMaxX - newMinX
            let currentH = currentW / ratio
            if deltaMinY != 0 {
                newMinY = max(imageRenderRect.minY, newMaxY - currentH)
            } else {
                newMaxY = min(imageRenderRect.maxY, newMinY + currentH)
            }
        }
        
        cropRect = CGRect(x: newMinX, y: newMinY, width: max(30, newMaxX - newMinX), height: max(30, newMaxY - newMinY))
        syncTextWithCropRect()
    }
    
    private func syncTextWithCropRect() {
        guard pixelSize.width > 0, imageRenderRect.width > 0 else { return }
        let cropPixelW = Int(round((cropRect.width / imageRenderRect.width) * pixelSize.width))
        let cropPixelH = Int(round((cropRect.height / imageRenderRect.height) * pixelSize.height))
        inputWidthText = "\(cropPixelW)"
        inputHeightText = "\(cropPixelH)"
    }
    
    private func applyTypedPixelDimensions() {
        let cleanW = inputWidthText.filter { $0.isNumber }
        let cleanH = inputHeightText.filter { $0.isNumber }
        guard let typedW = Int(cleanW),
              let typedH = Int(cleanH),
              pixelSize.width > 0, pixelSize.height > 0,
              imageRenderRect.width > 0, imageRenderRect.height > 0 else {
            syncTextWithCropRect()
            return
        }
        
        let clampedW = CGFloat(min(max(typedW, 20), Int(pixelSize.width)))
        let clampedH = CGFloat(min(max(typedH, 20), Int(pixelSize.height)))
        
        let viewW = (clampedW / pixelSize.width) * imageRenderRect.width
        let viewH = (clampedH / pixelSize.height) * imageRenderRect.height
        
        var newOriginX = cropRect.midX - viewW / 2
        var newOriginY = cropRect.midY - viewH / 2
        
        newOriginX = max(imageRenderRect.minX, min(newOriginX, imageRenderRect.maxX - viewW))
        newOriginY = max(imageRenderRect.minY, min(newOriginY, imageRenderRect.maxY - viewH))
        
        selectedAspectRatio = .free
        cropRect = CGRect(x: newOriginX, y: newOriginY, width: viewW, height: viewH)
        syncTextWithCropRect()
    }
    
    private func performCrop() {
        guard let cgImg = cgImage, imageRenderRect.width > 0, imageRenderRect.height > 0 else {
            onComplete(nil)
            return
        }
        
        // Exact normalized coordinates relative to imageRenderRect (0.0 ... 1.0)
        let normX = max(0, (cropRect.minX - imageRenderRect.minX) / imageRenderRect.width)
        let normY = max(0, (cropRect.minY - imageRenderRect.minY) / imageRenderRect.height)
        let normW = min(1.0 - normX, cropRect.width / imageRenderRect.width)
        let normH = min(1.0 - normY, cropRect.height / imageRenderRect.height)
        
        // Exact pixel coordinates
        let pixelX = normX * pixelSize.width
        let pixelY = normY * pixelSize.height
        let pixelW = normW * pixelSize.width
        let pixelH = normH * pixelSize.height
        
        let pixelCropRect = CGRect(
            x: pixelX,
            y: pixelY,
            width: max(1, pixelW),
            height: max(1, pixelH)
        )
        
        guard let croppedCG = cgImg.cropping(to: pixelCropRect) else {
            onComplete(nil)
            return
        }
        
        let parentDir = fileURL.deletingLastPathComponent()
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName)_cropped.png")
        
        let newRep = NSBitmapImageRep(cgImage: croppedCG)
        if let pngData = newRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: outputURL)
            onComplete(outputURL)
        } else {
            onComplete(nil)
        }
    }
}

public final class CropWindowController {
    public static let shared = CropWindowController()
    private var window: NSWindow?
    
    public func show(for url: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Crop Image"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        
        let cropView = CropView(fileURL: url) { [weak window] resultURL in
            window?.close()
            if let result = resultURL {
                NotificationManager.shared.send(
                    title: "크롭 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            }
        }
        
        window.contentView = NSHostingView(rootView: cropView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

public final class FocusSelectAllTextField: NSTextField {
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            DispatchQueue.main.async { [weak self] in
                if let editor = self?.currentEditor() {
                    editor.selectAll(nil)
                } else {
                    self?.selectText(nil)
                }
            }
        }
        return result
    }
    
    public override func mouseDown(with event: NSEvent) {
        let isAlreadyActive = (self.window?.firstResponder == self.currentEditor())
        super.mouseDown(with: event)
        if !isAlreadyActive {
            DispatchQueue.main.async { [weak self] in
                if let editor = self?.currentEditor() {
                    editor.selectAll(nil)
                } else {
                    self?.selectText(nil)
                }
            }
        }
    }
}

public struct NumericPixelTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    
    public func makeNSView(context: Context) -> FocusSelectAllTextField {
        let textField = FocusSelectAllTextField()
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        textField.alignment = .center
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        return textField
    }
    
    public func updateNSView(_ nsView: FocusSelectAllTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NumericPixelTextField
        
        init(_ parent: NumericPixelTextField) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                let filtered = textField.stringValue.filter { $0.isNumber }
                if filtered != textField.stringValue {
                    textField.stringValue = filtered
                }
                parent.text = filtered
            }
        }
        
        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
