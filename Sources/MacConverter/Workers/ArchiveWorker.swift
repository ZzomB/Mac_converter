import Foundation

public final class ArchiveWorker {
    
    // Silent background ZIP compression using macOS native ditto
    public static func createZip(urls: [URL], progress: @escaping (Double) -> Void) async throws -> URL {
        guard let first = urls.first else {
            throw NSError(domain: "ArchiveWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "압축할 파일이 지정되지 않았습니다."])
        }
        
        let parentDir = first.deletingLastPathComponent()
        let outputName: String
        if urls.count == 1 {
            outputName = "\(first.deletingPathExtension().lastPathComponent)_archived.zip"
        } else {
            outputName = "\(first.deletingPathExtension().lastPathComponent)_and_\(urls.count - 1)_others.zip"
        }
        
        let outputURL = parentDir.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)
        
        progress(0.2)
        
        // If single directory or single file
        if urls.count == 1 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", first.path, outputURL.path]
            
            progress(0.5)
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "ArchiveWorker", code: 2, userInfo: [NSLocalizedDescriptionKey: "압축 중 오류가 발생했습니다."])
            }
        } else {
            // Multiple items: create a temporary staging folder
            let tempStaging = parentDir.appendingPathComponent(".temp_archive_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempStaging, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempStaging)
            }
            
            for (i, url) in urls.enumerated() {
                let dest = tempStaging.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: dest)
                progress(0.2 + (0.4 * Double(i + 1) / Double(urls.count)))
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", tempStaging.path, outputURL.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "ArchiveWorker", code: 3, userInfo: [NSLocalizedDescriptionKey: "다중 파일 압축 중 오류가 발생했습니다."])
            }
        }
        
        progress(1.0)
        return outputURL
    }
}
