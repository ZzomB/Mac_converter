import SwiftUI
import AppKit

public struct ContextMenuView: View {
    let actions: [FileAction]
    let selectedFiles: [URL]
    @Binding var hoveredAction: FileAction?
    let onSelect: (FileAction) -> Void
    
    public init(
        actions: [FileAction],
        selectedFiles: [URL],
        hoveredAction: Binding<FileAction?>,
        onSelect: @escaping (FileAction) -> Void
    ) {
        self.actions = actions
        self.selectedFiles = selectedFiles
        self._hoveredAction = hoveredAction
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: Target summary
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("마우스를 놓아 실행 (Drop to Execute)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, 6)
            
            // Action list
            ForEach(actions) { action in
                let isHovered = (hoveredAction == action)
                
                HStack(spacing: 10) {
                    Image(systemName: action.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 20)
                        .foregroundColor(isHovered ? .primary : .secondary)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(action.displayName)
                            .font(.system(size: 13, weight: isHovered ? .semibold : .medium))
                            .foregroundColor(.primary)
                        
                        Text(action.subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside {
                        hoveredAction = action
                    } else if hoveredAction == action {
                        hoveredAction = nil
                    }
                }
                .onTapGesture {
                    onSelect(action)
                }
            }
        }
        .padding(6)
        .frame(width: 220)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
    }
}
