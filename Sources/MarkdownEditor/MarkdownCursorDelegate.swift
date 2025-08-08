import UIKit
import Lexical
import LexicalListPlugin

/// Delegate that provides block-type aware cursor customization
final class MarkdownCursorDelegate: NSObject, TextViewCursorDelegate {
    
    private let markdownTheme: MarkdownTheme
    
    init(theme: MarkdownTheme) {
        self.markdownTheme = theme
        super.init()
    }
    
    func textView(_ textView: TextView, cursorRectFor position: UITextPosition, defaultRect: CGRect) -> CGRect {
        var rect = defaultRect
        
        // Get the block node at cursor position
        let blockInfo = getBlockNodeAtCursor(from: textView, at: position)
        
        // Use the font size from the block node
        let fontSize = blockInfo.fontSize
        
        // Calculate cursor height based on font size and theme multiplier
        let cursorHeight = fontSize * markdownTheme.spacing.cursorHeightMultiplier
        
        // Set the cursor height
        rect.size.height = cursorHeight
        
        // Adjust vertical position based on theme offset
        // The offset is relative to the current position
        // 0.0 = keep at top, 0.5 = center, 1.0 = align to bottom
        let verticalOffset = markdownTheme.spacing.cursorVerticalOffset
        if verticalOffset > 0 {
            let adjustment = (cursorHeight - defaultRect.size.height) * verticalOffset
            rect.origin.y -= adjustment
        }
        
        // H2-specific nudge: caret sits visually a bit too high; push it down slightly more
        if blockInfo.headingTag == .h2 {
            let heightDelta = abs(cursorHeight - defaultRect.size.height)
            rect.origin.y += heightDelta * 0.8
        }
        
        return rect
    }
    
    private func getBlockNodeAtCursor(from textView: TextView, at position: UITextPosition) -> (node: Node?, fontSize: CGFloat, headingTag: HeadingTagType?) {
        var result: (node: Node?, fontSize: CGFloat, headingTag: HeadingTagType?) = (nil, 16.0, nil)
        
        do {
            try textView.editor.read {
                guard let selection = try getSelection() as? RangeSelection else {
                    return
                }
                
                let anchor = selection.anchor
                guard let anchorNode = try? anchor.getNode() else {
                    return
                }
                
                // Find the block-level parent node
                var blockNode: Node? = anchorNode
                while let node = blockNode {
                    // Check if this is a block-level node
                    if node is ParagraphNode || node is HeadingNode || node is ListItemNode {
                        result.node = node
                        break
                    }
                    blockNode = node.getParent()
                }
                
                // Determine font size based on node type and markdown theme
                if let headingNode = result.node as? HeadingNode {
                    result.headingTag = headingNode.getTag()
                    switch headingNode.getTag() {
                    case .h1:
                        result.fontSize = markdownTheme.typography.h1.pointSize
                    case .h2:
                        result.fontSize = markdownTheme.typography.h2.pointSize
                    case .h3:
                        result.fontSize = markdownTheme.typography.h3.pointSize
                    case .h4:
                        result.fontSize = markdownTheme.typography.h4.pointSize
                    case .h5:
                        result.fontSize = markdownTheme.typography.h5.pointSize
                    }
                } else if result.node is ListItemNode || result.node is ParagraphNode {
                    result.fontSize = markdownTheme.typography.body.pointSize
                }
            }
        } catch {
            // Silent fail - return defaults
        }
        
        return result
    }
}