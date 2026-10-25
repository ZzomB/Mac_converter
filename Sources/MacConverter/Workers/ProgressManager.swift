import Foundation
import SwiftUI
import Combine

@MainActor
public final class ProgressManager: ObservableObject {
    public static let shared = ProgressManager()
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentTaskName: String = ""
    @Published public private(set) var detailText: String = ""
    @Published public private(set) var progress: Double = 0.0 // 0.0 ~ 1.0
    @Published public private(set) var isCompleted: Bool = false
    @Published public private(set) var hasError: Bool = false
    @Published public private(set) var errorMessage: String = ""
    
    private var dismissWorkItem: DispatchWorkItem?
    
    private init() {}
    
    public func startTask(title: String, detail: String = "") {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        
        self.isRunning = true
        self.isCompleted = false
        self.hasError = false
        self.errorMessage = ""
        self.currentTaskName = title
        self.detailText = detail
        self.progress = 0.0
    }
    
    public func updateProgress(_ value: Double, detail: String? = nil) {
        guard isRunning else { return }
        self.progress = min(max(value, 0.0), 1.0)
        if let detail = detail {
            self.detailText = detail
        }
    }
    
    public func completeTask(title: String? = nil, message: String = "완료") {
        guard isRunning else { return }
        self.progress = 1.0
        self.isCompleted = true
        if let title = title {
            self.currentTaskName = title
        }
        self.detailText = message
        
        // Auto-dismiss HUD after 1.8 seconds
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.isCompleted = false
            self.progress = 0.0
            self.currentTaskName = ""
            self.detailText = ""
        }
        self.dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: item)
    }
    
    public func failTask(title: String? = nil, error: String) {
        self.hasError = true
        self.errorMessage = error
        self.detailText = error
        if let title = title {
            self.currentTaskName = title
        }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.hasError = false
            self.errorMessage = ""
        }
        self.dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }
}
