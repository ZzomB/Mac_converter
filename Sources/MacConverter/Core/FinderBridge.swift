import Foundation
import AppKit

public final class FinderBridge {
    public static func getSelectedFiles() -> [URL] {
        // 1. Check drag pasteboard first
        let dragPboard = NSPasteboard(name: .drag)
        if let urls = dragPboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return urls
        }
        
        // 2. Query Finder selection via AppleScript
        let scriptSource = """
        tell application "Finder"
            set sel to selection as alias list
            set pathList to {}
            repeat with itemRef in sel
                set end of pathList to POSIX path of itemRef
            end repeat
            return pathList
        end tell
        """
        
        guard let script = NSAppleScript(source: scriptSource) else {
            return []
        }
        
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        if let error = errorDict {
            print("AppleScript execution error: \(error)")
            return []
        }
        
        var results: [URL] = []
        if descriptor.descriptorType == typeAEList {
            for i in 1...descriptor.numberOfItems {
                if let itemDesc = descriptor.atIndex(i),
                   let path = itemDesc.stringValue {
                    let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanPath.isEmpty {
                        results.append(URL(fileURLWithPath: cleanPath))
                    }
                }
            }
        } else if let singlePath = descriptor.stringValue {
            let cleanPath = singlePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanPath.isEmpty {
                results.append(URL(fileURLWithPath: cleanPath))
            }
        }
        
        return results
    }
}
