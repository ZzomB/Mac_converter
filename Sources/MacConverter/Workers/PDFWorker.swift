import Foundation
import PDFKit
import CoreGraphics
import UniformTypeIdentifiers

public final class PDFWorker {
    
    // PDF to high-res PNG pages
    public static func pdfToPng(file: URL, progress: @escaping (Double) -> Void) async throws -> [URL] {
        guard let document = PDFDocument(url: file) else {
            throw NSError(domain: "PDFWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF 파일을 열 수 없습니다."])
        }
        
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw NSError(domain: "PDFWorker", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF에 페이지가 없습니다."])
        }
        
        let parentDir = file.deletingLastPathComponent()
        let baseName = file.deletingPathExtension().lastPathComponent
        let outputDir = parentDir.appendingPathComponent("\(baseName)_PNG")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var generatedFiles: [URL] = []
        
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            
            // Render at high resolution (300 DPI: scale factor ~ 3.0x of 72 DPI)
            let scale: CGFloat = 3.0
            let targetSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: Int(targetSize.width),
                    height: Int(targetSize.height),
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                continue
            }
            
            context.setFillColor(CGColor.white)
            context.fill(CGRect(origin: .zero, size: targetSize))
            context.saveGState()
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            
            guard let cgImage = context.makeImage() else { continue }
            
            let outputFileName = "\(baseName)_page_\(i + 1).png"
            let outputURL = outputDir.appendingPathComponent(outputFileName)
            
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                continue
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            CGImageDestinationFinalize(destination)
            
            generatedFiles.append(outputURL)
            let currentProgress = Double(i + 1) / Double(pageCount)
            progress(currentProgress)
        }
        
        return generatedFiles
    }
    
    // Multiple PNGs (or images) to single PDF
    public static func pngsToPdf(files: [URL], progress: @escaping (Double) -> Void) async throws -> URL {
        guard !files.isEmpty else {
            throw NSError(domain: "PDFWorker", code: 3, userInfo: [NSLocalizedDescriptionKey: "변환할 이미지 파일이 없습니다."])
        }
        
        // Sort files naturally by filename
        let sortedFiles = files.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        
        let parentDir = sortedFiles.first!.deletingLastPathComponent()
        let baseName = sortedFiles.first!.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName)_merged.pdf")
        
        let pdfDocument = PDFDocument()
        let total = sortedFiles.count
        
        for (index, file) in sortedFiles.enumerated() {
            guard let image = NSImage(contentsOf: file) else { continue }
            if let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: pdfDocument.pageCount)
            }
            let currentProgress = Double(index + 1) / Double(total)
            progress(currentProgress)
        }
        
        guard pdfDocument.pageCount > 0 else {
            throw NSError(domain: "PDFWorker", code: 4, userInfo: [NSLocalizedDescriptionKey: "PDF에 추가된 페이지가 없습니다."])
        }
        
        pdfDocument.write(to: outputURL)
        return outputURL
    }
    
    // Merge multiple PDFs into one
    public static func mergePdfs(files: [URL], progress: @escaping (Double) -> Void) async throws -> URL {
        guard !files.isEmpty else {
            throw NSError(domain: "PDFWorker", code: 5, userInfo: [NSLocalizedDescriptionKey: "병합할 PDF 파일이 없습니다."])
        }
        
        let sortedFiles = files.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        
        let parentDir = sortedFiles.first!.deletingLastPathComponent()
        let baseName = sortedFiles.first!.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName)_all_merged.pdf")
        
        let finalDocument = PDFDocument()
        let totalFiles = sortedFiles.count
        
        for (fIndex, file) in sortedFiles.enumerated() {
            guard let doc = PDFDocument(url: file) else { continue }
            for pIndex in 0..<doc.pageCount {
                if let page = doc.page(at: pIndex) {
                    finalDocument.insert(page, at: finalDocument.pageCount)
                }
            }
            let currentProgress = Double(fIndex + 1) / Double(totalFiles)
            progress(currentProgress)
        }
        
        finalDocument.write(to: outputURL)
        return outputURL
    }
}
