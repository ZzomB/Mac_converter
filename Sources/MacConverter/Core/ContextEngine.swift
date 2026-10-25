import Foundation
import UniformTypeIdentifiers

public enum ActionCategory {
    case conversion // Shortcut A (형식 변환)
    case processing // Shortcut B (파일 가공)
}

public enum FileAction: String, CaseIterable, Identifiable {
    // Shortcut A: Conversion Actions
    case pdfToPng
    case pngToPdf
    case heicToJpg
    case heicToPng
    case officeToPdf
    case mergePdf
    
    // Shortcut B: Processing Actions
    case removeBg
    case crop
    case optimizeImage
    case videoToGif
    case extractAudio
    case zipArchive
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .pdfToPng: return "PNG"
        case .pngToPdf: return "PDF"
        case .heicToJpg: return "JPG"
        case .heicToPng: return "PNG"
        case .officeToPdf: return "PDF"
        case .mergePdf: return "PDF 병합"
        case .removeBg: return "누끼 따기"
        case .crop: return "Crop"
        case .optimizeImage: return "용량 최적화"
        case .videoToGif: return "GIF"
        case .extractAudio: return "음원 추출"
        case .zipArchive: return "ZIP 압축"
        }
    }
    
    public var iconName: String {
        switch self {
        case .pdfToPng: return "photo.stack"
        case .pngToPdf: return "doc.richtext"
        case .heicToJpg: return "photo"
        case .heicToPng: return "photo.fill"
        case .officeToPdf: return "doc.text.fill"
        case .mergePdf: return "doc.on.doc.fill"
        case .removeBg: return "person.crop.rectangle"
        case .crop: return "crop"
        case .optimizeImage: return "arrow.down.circle"
        case .videoToGif: return "play.square.stack"
        case .extractAudio: return "waveform"
        case .zipArchive: return "archivebox.fill"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .pdfToPng: return "각 페이지 고해상도 분할"
        case .pngToPdf: return "이미지 순서 정렬 병합"
        case .heicToJpg: return "범용 JPG 일괄 변환"
        case .heicToPng: return "무손실 PNG 변환"
        case .officeToPdf: return "문서 PDF 변환"
        case .mergePdf: return "선택 PDF 하나로 통합"
        case .removeBg: return "배경 투명 분리 (Apple Vision)"
        case .crop: return "네이티브 화면 크롭"
        case .optimizeImage: return "화질 유지 용량 다이어트"
        case .videoToGif: return "공유용 고품질 애니메이션"
        case .extractAudio: return "비디오 제거 M4A/MP3"
        case .zipArchive: return "백그라운드 무음 압축"
        }
    }
}

public final class ContextEngine {
    public static func determineActions(for urls: [URL], category: ActionCategory) -> [FileAction] {
        guard !urls.isEmpty else { return [] }
        
        let extensions = urls.map { $0.pathExtension.lowercased() }
        let count = urls.count
        
        let isAllPdf = extensions.allSatisfy { $0 == "pdf" }
        let isAllPng = extensions.allSatisfy { $0 == "png" }
        let isAllHeic = extensions.allSatisfy { $0 == "heic" || $0 == "heif" }
        let isAllImages = extensions.allSatisfy { ["png", "jpg", "jpeg", "heic", "webp"].contains($0) }
        let isAllOffice = extensions.allSatisfy { ["pptx", "docx", "xlsx", "ppt", "doc", "xls", "key", "pages"].contains($0) }
        let isAllVideos = extensions.allSatisfy { ["mov", "mp4", "m4v", "avi", "mkv"].contains($0) }
        
        switch category {
        case .conversion:
            // Shortcut A: Format Conversion
            if count == 1 && isAllPdf {
                return [.pdfToPng]
            } else if count > 1 && isAllPng {
                return [.pngToPdf]
            } else if isAllHeic {
                return [.heicToJpg, .heicToPng]
            } else if isAllOffice {
                return [.officeToPdf]
            } else if count > 1 && isAllPdf {
                return [.mergePdf]
            } else if count > 1 && isAllImages {
                return [.pngToPdf]
            } else {
                return []
            }
            
        case .processing:
            // Shortcut B: File Processing
            var actions: [FileAction] = []
            
            if count == 1 && (isAllImages || isAllPng) {
                actions.append(.removeBg)
                actions.append(.crop)
                actions.append(.optimizeImage)
            } else if count > 1 && isAllImages {
                actions.append(.optimizeImage)
                actions.append(.zipArchive)
            } else if isAllVideos {
                actions.append(.extractAudio)
                actions.append(.videoToGif)
                actions.append(.zipArchive)
            } else {
                // Generic files or folders
                actions.append(.zipArchive)
            }
            return actions
        }
    }
}
