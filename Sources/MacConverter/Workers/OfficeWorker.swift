import Foundation
import AppKit

public final class OfficeWorker {
    
    // Checks if an application with bundle identifier is installed
    private static func isAppInstalled(bundleId: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    // Finds LibreOffice binary if available
    private static func findSofficeBinary() -> String? {
        let possiblePaths = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/soffice",
            "/usr/local/bin/soffice"
        ]
        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    // Generates a fontconfig configuration file that includes macOS Korean and CJK fonts
    private static func ensureFontConfigFile() -> String {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        let configDir = appSupport.appendingPathComponent("MacConverter", isDirectory: true)
        try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let configFile = configDir.appendingPathComponent("fonts.conf")
        
        let configXML = """
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <!-- Microsoft Office Official Fonts (Malgun Gothic, Batang, Gulim, Calibri, Aptos, etc.) -->
          <dir>/Applications/Microsoft Word.app/Contents/Resources/DFonts</dir>
          <dir>/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts</dir>
          <dir>/Applications/Microsoft Excel.app/Contents/Resources/DFonts</dir>
          <dir>/Library/Application Support/Microsoft/Fonts</dir>
          
          <!-- macOS System Font Directories -->
          <dir>/System/Library/Fonts</dir>
          <dir>/System/Library/Fonts/Supplemental</dir>
          <dir>/Library/Fonts</dir>
          <dir>~/Library/Fonts</dir>
          <dir>/Applications/LibreOffice.app/Contents/Resources/fonts/truetype</dir>
          
          <!-- Font Aliases with True Metric Preference -->
          <alias>
            <family>맑은 고딕</family>
            <prefer>
              <family>Malgun Gothic</family>
              <family>Apple SD Gothic Neo</family>
            </prefer>
          </alias>
          <alias>
            <family>Malgun Gothic</family>
            <prefer>
              <family>맑은 고딕</family>
              <family>Apple SD Gothic Neo</family>
            </prefer>
          </alias>
          <alias>
            <family>바탕</family>
            <prefer>
              <family>Batang</family>
              <family>AppleMyungjo</family>
            </prefer>
          </alias>
          <alias>
            <family>Batang</family>
            <prefer>
              <family>바탕</family>
              <family>AppleMyungjo</family>
            </prefer>
          </alias>
          <alias>
            <family>굴림</family>
            <prefer>
              <family>Gulim</family>
              <family>AppleGothic</family>
            </prefer>
          </alias>
          <alias>
            <family>Gulim</family>
            <prefer>
              <family>굴림</family>
              <family>AppleGothic</family>
            </prefer>
          </alias>
          <alias>
            <family>돋움</family>
            <prefer>
              <family>Dotum</family>
              <family>Apple SD Gothic Neo</family>
            </prefer>
          </alias>
          <alias>
            <family>Dotum</family>
            <prefer>
              <family>돋움</family>
              <family>Apple SD Gothic Neo</family>
            </prefer>
          </alias>
          <alias>
            <family>나눔고딕</family>
            <prefer>
              <family>NanumGothic</family>
              <family>Apple SD Gothic Neo</family>
            </prefer>
          </alias>
          <alias>
            <family>나눔명조</family>
            <prefer>
              <family>NanumMyeongjo</family>
              <family>AppleMyungjo</family>
            </prefer>
          </alias>

          <!-- Fallback for Korean Language -->
          <match target="pattern">
            <test name="lang"><string>ko</string></test>
            <edit name="family" mode="prepend" binding="strong">
              <string>Malgun Gothic</string>
              <string>Apple SD Gothic Neo</string>
            </edit>
          </match>
        </fontconfig>
        """
        
        try? configXML.write(to: configFile, atomically: true, encoding: .utf8)
        return configFile.path
    }
    
    // Converts a Word document (.docx, .doc) using Microsoft Word natively with zero sandbox dialogs and hidden window
    private static func convertWithNativeWord(file: URL, outputURL: URL) -> Bool {
        guard isAppInstalled(bundleId: "com.microsoft.Word") else { return false }
        
        let ext = file.pathExtension.lowercased()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appendingPathComponent("Library/Containers/com.microsoft.Word/Data")
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        
        let uuid = UUID().uuidString
        let tempDocx = container.appendingPathComponent("conv_\(uuid).\(ext)")
        let tempPdf = container.appendingPathComponent("conv_\(uuid).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: tempDocx)
            try? FileManager.default.removeItem(at: tempPdf)
        }
        
        do {
            try FileManager.default.copyItem(at: file, to: tempDocx)
        } catch {
            return false
        }
        
        let wasWordRunning = (NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first != nil)
        
        let script = """
        set docPath to "\(tempDocx.path)"
        set pdfPath to "\(tempPdf.path)"
        
        tell application id "com.microsoft.Word"
            set display alerts to none
            open (POSIX file docPath)
            set theDoc to active document
            set visible of window 1 to false
            save as theDoc file name pdfPath file format format PDF
            close theDoc saving no
            if not \(wasWordRunning) then
                quit
            end if
        end tell
        """
        
        var err: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&err)
            if err != nil {
                return false
            }
        }
        
        if FileManager.default.fileExists(atPath: tempPdf.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: tempPdf.path),
           (attr[.size] as? Int64 ?? 0) > 0 {
            try? FileManager.default.removeItem(at: outputURL)
            do {
                try FileManager.default.moveItem(at: tempPdf, to: outputURL)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    // Converts a PowerPoint document (.pptx, .ppt) using Microsoft PowerPoint natively with zero sandbox dialogs
    private static func convertWithNativePowerPoint(file: URL, outputURL: URL) -> Bool {
        guard isAppInstalled(bundleId: "com.microsoft.Powerpoint") else { return false }
        
        let ext = file.pathExtension.lowercased()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data")
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        
        let uuid = UUID().uuidString
        let tempPptx = container.appendingPathComponent("conv_\(uuid).\(ext)")
        let tempPdf = container.appendingPathComponent("conv_\(uuid).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: tempPptx)
            try? FileManager.default.removeItem(at: tempPdf)
        }
        
        do {
            try FileManager.default.copyItem(at: file, to: tempPptx)
        } catch {
            return false
        }
        
        let wasPptRunning = (NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Powerpoint").first != nil)
        
        let script = """
        set pptxPath to "\(tempPptx.path)"
        set pdfFile to (POSIX file "\(tempPdf.path)")
        
        tell application id "com.microsoft.Powerpoint"
            open (POSIX file pptxPath)
            set thePres to active presentation
            save thePres in pdfFile as save as PDF
            close thePres saving no
            if not \(wasPptRunning) then
                quit
            end if
        end tell
        """
        
        var err: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&err)
            if err != nil {
                return false
            }
        }
        
        if FileManager.default.fileExists(atPath: tempPdf.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: tempPdf.path),
           (attr[.size] as? Int64 ?? 0) > 0 {
            try? FileManager.default.removeItem(at: outputURL)
            do {
                try FileManager.default.moveItem(at: tempPdf, to: outputURL)
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    // Converts an Excel document (.xlsx, .xls) using Microsoft Excel natively with zero sandbox dialogs
    private static func convertWithNativeExcel(file: URL, outputURL: URL) -> Bool {
        guard isAppInstalled(bundleId: "com.microsoft.Excel") else { return false }
        
        let ext = file.pathExtension.lowercased()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appendingPathComponent("Library/Containers/com.microsoft.Excel/Data")
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        
        let uuid = UUID().uuidString
        let tempXlsx = container.appendingPathComponent("conv_\(uuid).\(ext)")
        let tempPdf = container.appendingPathComponent("conv_\(uuid).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: tempXlsx)
            try? FileManager.default.removeItem(at: tempPdf)
        }
        
        do {
            try FileManager.default.copyItem(at: file, to: tempXlsx)
        } catch {
            return false
        }
        
        let wasExcelRunning = (NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Excel").first != nil)
        
        let script = """
        set xlsxPath to "\(tempXlsx.path)"
        set pdfFile to (POSIX file "\(tempPdf.path)")
        
        tell application id "com.microsoft.Excel"
            set display alerts to false
            open (POSIX file xlsxPath)
            set theBook to active workbook
            save active workbook in pdfFile as PDF file format
            close theBook saving no
            if not \(wasExcelRunning) then
                quit
            end if
        end tell
        """
        
        var err: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&err)
            if err != nil {
                return false
            }
        }
        
        if FileManager.default.fileExists(atPath: tempPdf.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: tempPdf.path),
           (attr[.size] as? Int64 ?? 0) > 0 {
            try? FileManager.default.removeItem(at: outputURL)
            do {
                try FileManager.default.moveItem(at: tempPdf, to: outputURL)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    // Converts Office documents (PPTX, DOCX, XLSX, KEY, PAGES) to PDF
    public static func convertOfficeToPdf(file: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        progress(0.15)
        
        let ext = file.pathExtension.lowercased()
        let parentDir = file.deletingLastPathComponent()
        let baseName = file.deletingPathExtension().lastPathComponent
        let outputURL = parentDir.appendingPathComponent("\(baseName).pdf")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        // Priority 1: Native MS Word for docx/doc (100% identical line breaks, character-level word wrap, zero permission prompts)
        if ["docx", "doc"].contains(ext) {
            progress(0.25)
            if convertWithNativeWord(file: file, outputURL: outputURL) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Priority 1: Native MS PowerPoint for pptx/ppt (100% identical layout, fonts, zero permission prompts)
        if ["pptx", "ppt"].contains(ext) {
            progress(0.25)
            if convertWithNativePowerPoint(file: file, outputURL: outputURL) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Priority 1: Native MS Excel for xlsx/xls (100% identical sheets, zero permission prompts)
        if ["xlsx", "xls"].contains(ext) {
            progress(0.25)
            if convertWithNativeExcel(file: file, outputURL: outputURL) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Priority 2: Apple Pages for .pages
        if ext == "pages" && isAppInstalled(bundleId: "com.apple.iWork.Pages") {
            progress(0.3)
            let filePath = file.path.replacingOccurrences(of: "\"", with: "\\\"")
            let outPath = outputURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let scriptSource = """
            tell application id "com.apple.iWork.Pages"
                set theDoc to open POSIX file "\(filePath)" with hidden
                delay 0.3
                export theDoc to POSIX file "\(outPath)" as PDF
                close theDoc saving no
            end tell
            """
            var errorDict: NSDictionary?
            let script = NSAppleScript(source: scriptSource)
            script?.executeAndReturnError(&errorDict)
            if FileManager.default.fileExists(atPath: outputURL.path) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Priority 2: Apple Keynote for .key
        if ext == "key" && isAppInstalled(bundleId: "com.apple.iWork.Keynote") {
            progress(0.3)
            let filePath = file.path.replacingOccurrences(of: "\"", with: "\\\"")
            let outPath = outputURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let scriptSource = """
            tell application id "com.apple.iWork.Keynote"
                set theDoc to open POSIX file "\(filePath)" with hidden
                delay 0.3
                export theDoc to POSIX file "\(outPath)" as PDF
                close theDoc saving no
            end tell
            """
            var errorDict: NSDictionary?
            let script = NSAppleScript(source: scriptSource)
            script?.executeAndReturnError(&errorDict)
            if FileManager.default.fileExists(atPath: outputURL.path) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Priority 3: LibreOffice Headless with MS DFonts FontConfig (Silent fallback)
        if let soffice = findSofficeBinary() {
            progress(0.5)
            let fontConfigFile = ensureFontConfigFile()
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: soffice)
            process.arguments = ["--headless", "--convert-to", "pdf", file.path, "--outdir", parentDir.path]
            
            var env = ProcessInfo.processInfo.environment
            env["FONTCONFIG_FILE"] = fontConfigFile
            process.environment = env
            
            try? process.run()
            process.waitUntilExit()
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                progress(1.0)
                return outputURL
            }
        }
        
        // Fallback: QuickLook thumbnail/pdf generator (qlmanage)
        progress(0.8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-p", file.path, "-o", parentDir.path]
        try? process.run()
        process.waitUntilExit()
        
        progress(1.0)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        } else {
            let isPresentation = ["key", "pptx", "ppt"].contains(ext)
            let appNeeded = isPresentation ? "PowerPoint" : "Word"
            throw NSError(
                domain: "OfficeWorker",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(appNeeded) 또는 LibreOffice 변환에 실패했습니다."]
            )
        }
    }
}
