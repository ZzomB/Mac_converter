import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

public enum TargetImageFormat {
    case jpg
    case png
    
    var utType: UTType {
        switch self {
        case .jpg: return .jpeg
        case .png: return .png
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        }
    }
}

public enum OptimizationFormatMode: String, CaseIterable, Identifiable {
    case keepOriginal = "원본 포맷 유지"
    case convertToJpg = "JPG로 변환 (용량 대폭 절감)"
    
    public var id: String { rawValue }
}

public struct ImageOptimizationSettings {
    public var scalePercentage: Double // 1.0 = 100%, 0.75 = 75%, 0.5 = 50%, 0.25 = 25%
    public var customMaxWidth: CGFloat?
    public var quality: Double // 0.60 ~ 0.90
    public var formatMode: OptimizationFormatMode
    
    public init(
        scalePercentage: Double = 0.5,
        customMaxWidth: CGFloat? = nil,
        quality: Double = 0.75,
        formatMode: OptimizationFormatMode = .keepOriginal
    ) {
        self.scalePercentage = scalePercentage
        self.customMaxWidth = customMaxWidth
        self.quality = quality
        self.formatMode = formatMode
    }
}

public final class ImageOptimizationWorker {
    
    // HEIC to JPG or PNG
    public static func convertHeic(
        files: [URL],
        targetFormat: TargetImageFormat,
        progress: @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard !files.isEmpty else { return [] }
        
        var results: [URL] = []
        let total = files.count
        
        for (index, file) in files.enumerated() {
            guard let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }
            
            let parentDir = file.deletingLastPathComponent()
            let baseName = file.deletingPathExtension().lastPathComponent
            let outputURL = parentDir.appendingPathComponent("\(baseName).\(targetFormat.fileExtension)")
            
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, targetFormat.utType.identifier as CFString, 1, nil) else {
                continue
            }
            
            var options: [CFString: Any] = [:]
            if targetFormat == .jpg {
                options[kCGImageDestinationLossyCompressionQuality] = 0.90
            }
            
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            CGImageDestinationFinalize(destination)
            
            results.append(outputURL)
            progress(Double(index + 1) / Double(total))
        }
        
        return results
    }
    
    // Advanced Optimize with interactive settings
    public static func optimizeImagesWithSettings(
        files: [URL],
        settings: ImageOptimizationSettings,
        progress: @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard !files.isEmpty else { return [] }
        
        var results: [URL] = []
        let total = files.count
        
        for (index, file) in files.enumerated() {
            guard let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil) else {
                continue
            }
            
            // Extract original image properties
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                  let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
                continue
            }
            
            // Calculate target pixel dimensions
            let targetMaxDimension: CGFloat
            if let customMax = settings.customMaxWidth {
                targetMaxDimension = min(customMax, max(pixelWidth, pixelHeight))
            } else {
                targetMaxDimension = max(pixelWidth, pixelHeight) * CGFloat(settings.scalePercentage)
            }
            
            // Create high-quality downsampled CGImage
            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(round(max(32, targetMaxDimension))),
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let scaledCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbOptions as CFDictionary) else {
                continue
            }
            
            let originalExt = file.pathExtension.lowercased()
            let parentDir = file.deletingLastPathComponent()
            let baseName = file.deletingPathExtension().lastPathComponent
            
            let targetExt: String
            let targetUTI: CFString
            let isJpg: Bool
            
            if settings.formatMode == .convertToJpg {
                targetExt = "jpg"
                targetUTI = UTType.jpeg.identifier as CFString
                isJpg = true
            } else {
                if originalExt == "png" {
                    targetExt = "png"
                    targetUTI = UTType.png.identifier as CFString
                    isJpg = false
                } else {
                    targetExt = "jpg"
                    targetUTI = UTType.jpeg.identifier as CFString
                    isJpg = true
                }
            }
            
            let outputURL = parentDir.appendingPathComponent("\(baseName)_optimized.\(targetExt)")
            
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, targetUTI, 1, nil) else {
                continue
            }
            
            var options: [CFString: Any] = [:]
            if isJpg {
                options[kCGImageDestinationLossyCompressionQuality] = settings.quality
            }
            
            CGImageDestinationAddImage(destination, scaledCGImage, options as CFDictionary)
            CGImageDestinationFinalize(destination)
            
            results.append(outputURL)
            progress(Double(index + 1) / Double(total))
        }
        
        return results
    }
    
    // Quick default optimize (fallback)
    public static func optimizeImages(
        files: [URL],
        progress: @escaping (Double) -> Void
    ) async throws -> [URL] {
        let defaultSettings = ImageOptimizationSettings(scalePercentage: 0.75, quality: 0.78, formatMode: .keepOriginal)
        return try await optimizeImagesWithSettings(files: files, settings: defaultSettings, progress: progress)
    }
}
