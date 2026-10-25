import Foundation
import AppKit

public final class ActionDispatcher {
    
    public static func dispatch(action: FileAction, files: [URL]) async {
        guard let first = files.first else { return }
        
        switch action {
        case .pdfToPng:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "PDF 페이지 분할", detail: first.lastPathComponent)
            }
            do {
                let results = try await PDFWorker.pdfToPng(file: first) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 추출 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "PNG 추출 완료", message: "\(results.count)개 이미지 생성")
                }
                let folderURL = results.first?.deletingLastPathComponent()
                NotificationManager.shared.send(
                    title: "PDF 분할 완료",
                    body: "\(folderURL?.lastPathComponent ?? "폴더")에 \(results.count)개의 PNG 이미지가 생성되었습니다.",
                    fileURL: folderURL
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .pngToPdf:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "PDF 병합 생성", detail: "\(files.count)개 이미지")
            }
            do {
                let result = try await PDFWorker.pngsToPdf(files: files) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 병합 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "PDF 생성 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "PDF 생성 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .mergePdf:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "PDF 병합", detail: "\(files.count)개 문서")
            }
            do {
                let result = try await PDFWorker.mergePdfs(files: files) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 통합 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "PDF 병합 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "PDF 병합 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .heicToJpg:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "HEIC ➔ JPG 변환", detail: "\(files.count)개 파일")
            }
            do {
                let results = try await ImageOptimizationWorker.convertHeic(files: files, targetFormat: .jpg) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 변환 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "JPG 변환 완료", message: "\(results.count)개 파일 생성")
                }
                NotificationManager.shared.send(
                    title: "JPG 변환 완료",
                    body: "\(results.count)개 파일이 변환되었습니다.",
                    fileURL: results.first
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .heicToPng:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "HEIC ➔ PNG 변환", detail: "\(files.count)개 파일")
            }
            do {
                let results = try await ImageOptimizationWorker.convertHeic(files: files, targetFormat: .png) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 변환 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "PNG 변환 완료", message: "\(results.count)개 파일 생성")
                }
                NotificationManager.shared.send(
                    title: "PNG 변환 완료",
                    body: "\(results.count)개 파일이 변환되었습니다.",
                    fileURL: results.first
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .officeToPdf:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "오피스 문서 변환", detail: first.lastPathComponent)
            }
            do {
                let result = try await OfficeWorker.convertOfficeToPdf(file: first) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 렌더링 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "PDF 변환 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "PDF 변환 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .removeBg:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "누끼 따기 (배경 제거)", detail: first.lastPathComponent)
            }
            do {
                let result = try await VisionWorker.removeBackground(file: first) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 피사체 분리 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "누끼 따기 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "누끼 따기 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .crop:
            await MainActor.run {
                CropWindowController.shared.show(for: first)
            }
            
        case .optimizeImage:
            await MainActor.run {
                ImageOptimizeWindowController.shared.show(for: files)
            }
            
        case .extractAudio:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "비디오 음원 추출", detail: first.lastPathComponent)
            }
            do {
                let result = try await MediaWorker.extractAudio(file: first) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 추출 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "음원 추출 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "음원 추출 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
            
        case .videoToGif:
            await MainActor.run {
                GifTrimWindowController.shared.show(for: first)
            }
            
        case .zipArchive:
            await MainActor.run {
                ProgressManager.shared.startTask(title: "ZIP 무음 압축", detail: "\(files.count)개 항목")
            }
            do {
                let result = try await ArchiveWorker.createZip(urls: files) { progress in
                    Task { @MainActor in
                        ProgressManager.shared.updateProgress(progress, detail: "\(Int(progress * 100))% 압축 중")
                    }
                }
                await MainActor.run {
                    ProgressManager.shared.completeTask(title: "ZIP 압축 완료", message: result.lastPathComponent)
                }
                NotificationManager.shared.send(
                    title: "ZIP 압축 완료",
                    body: result.lastPathComponent,
                    fileURL: result
                )
            } catch {
                await MainActor.run {
                    ProgressManager.shared.failTask(title: "오류", error: error.localizedDescription)
                }
            }
        }
    }
}
