import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public final class MediaWorker {
    
    // Video to Audio (M4A) extraction
    public static func extractAudio(file: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        let asset = AVAsset(url: file)
        
        let parentDir = file.deletingLastPathComponent()
        let baseName = file.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName).m4a")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "MediaWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "오디오 내보내기 세션을 생성할 수 없습니다."])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Start export
        await exportSession.export()
        
        var isDone = false
        Task {
            while !isDone {
                progress(Double(exportSession.progress))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        switch exportSession.status {
        case .completed:
            isDone = true
            progress(1.0)
            return outputURL
        case .failed:
            isDone = true
            throw exportSession.error ?? NSError(domain: "MediaWorker", code: 2, userInfo: [NSLocalizedDescriptionKey: "음원 추출에 실패했습니다."])
        case .cancelled:
            isDone = true
            throw NSError(domain: "MediaWorker", code: 3, userInfo: [NSLocalizedDescriptionKey: "작업이 취소되었습니다."])
        default:
            isDone = true
            return outputURL
        }
    }
    
    // Video to Animated GIF with customized start & end time
    public static func videoToGif(
        file: URL,
        startTime: Double = 0.0,
        endTime: Double? = nil,
        fps: Int = 10,
        maxWidth: CGFloat = 640,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVAsset(url: file)
        let durationTime = try await asset.load(.duration)
        let videoDuration = CMTimeGetSeconds(durationTime)
        
        let start = max(0.0, min(startTime, videoDuration))
        let end = min(endTime ?? min(videoDuration, start + 10.0), videoDuration)
        let actualDuration = max(0.2, end - start)
        
        let parentDir = file.deletingLastPathComponent()
        let baseName = file.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName).gif")
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        
        let frameCount = max(Int(actualDuration * Double(fps)), 1)
        
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw NSError(domain: "MediaWorker", code: 6, userInfo: [NSLocalizedDescriptionKey: "GIF 대상을 생성할 수 없습니다."])
        }
        
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0 // Infinite loop
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        let frameDuration = 1.0 / Double(fps)
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDuration
            ]
        ]
        
        for i in 0..<frameCount {
            let currentSec = start + (Double(i) * frameDuration)
            let time = CMTime(seconds: currentSec, preferredTimescale: 600)
            if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
                CGImageDestinationAddImage(destination, imageRef, frameProperties as CFDictionary)
            }
            progress(Double(i + 1) / Double(frameCount))
        }
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MediaWorker", code: 7, userInfo: [NSLocalizedDescriptionKey: "GIF 파일 저장에 실패했습니다."])
        }
        
        return outputURL
    }
}
