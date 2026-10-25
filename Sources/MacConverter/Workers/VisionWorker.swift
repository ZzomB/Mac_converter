import Foundation
import Vision
import CoreImage
import CoreGraphics
import UniformTypeIdentifiers
import AppKit

public final class VisionWorker {
    
    // Background removal (누끼 따기) using native Apple Vision Framework
    public static func removeBackground(file: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        progress(0.1)
        
        guard let inputImage = CIImage(contentsOf: file) else {
            throw NSError(domain: "VisionWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "이미지를 읽을 수 없습니다."])
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage, options: [:])
        
        progress(0.3)
        try handler.perform([request])
        
        guard let result = request.results?.first else {
            throw NSError(domain: "VisionWorker", code: 2, userInfo: [NSLocalizedDescriptionKey: "피사체 인식에 실패했습니다."])
        }
        
        progress(0.6)
        
        // Generate mask CVPixelBuffer
        let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Blend original image with mask to isolate foreground
        let filter = CIFilter(name: "CIBlendWithMask")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        filter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
        
        guard let outputCIImage = filter?.outputImage else {
            throw NSError(domain: "VisionWorker", code: 3, userInfo: [NSLocalizedDescriptionKey: "배경 분리 합성에 실패했습니다."])
        }
        
        progress(0.8)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            throw NSError(domain: "VisionWorker", code: 4, userInfo: [NSLocalizedDescriptionKey: "결과 이미지 생성에 실패했습니다."])
        }
        
        let parentDir = file.deletingLastPathComponent()
        let baseName = file.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName)_nobg.png")
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "VisionWorker", code: 5, userInfo: [NSLocalizedDescriptionKey: "출력 파일 생성에 실패했습니다."])
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        
        progress(1.0)
        return outputURL
    }
}
