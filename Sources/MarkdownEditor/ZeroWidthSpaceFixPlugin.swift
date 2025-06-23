import Foundation
import Lexical
import LexicalListPlugin

// MARK: - Zero Width Space Fix Plugin

/// A plugin that fixes the backspace issue where deleting a list item with zero-width space
/// takes two backspaces instead of one. This plugin intercepts deleteCharacter commands
/// and handles the special case of list items containing only zero-width space.
public class ZeroWidthSpaceFixPlugin: Plugin {
    
    public init() {}
    
    weak var editor: Editor?
    
    public func setUp(editor: Editor) {
        self.editor = editor
        
        // Register a high-priority command handler for deleteCharacter that runs before the default one
        _ = editor.registerCommand(
            type: .deleteCharacter,
            listener: { [weak self] payload in
                return self?.handleDeleteCharacter() ?? false
            })
    }
    
    public func tearDown() {
        self.editor = nil
    }
    
    /// Handles the deleteCharacter command with special logic for zero-width space
    /// Returns true if the command was handled, false to let the default handler process it
    private func handleDeleteCharacter() -> Bool {
        guard let editor = self.editor else { return false }
        
        do {
            var shouldInterceptDeletion = false
            
            // Check if we're in a special case that needs interception
            try editor.read {
                guard let selection = try getSelection() as? RangeSelection else { return }
                
                // Only handle backward deletion when selection is collapsed
                if !selection.isCollapsed() {
                    return
                }
                
                // Check if we're at the beginning of a list item containing only zero-width space
                let anchor = selection.anchor
                if anchor.offset == 0 && anchor.type == .element {
                    if let anchorNode = try? anchor.getNode() as? ListItemNode {
                        shouldInterceptDeletion = isListItemOnlyZeroWidthSpace(anchorNode)
                    }
                } else if anchor.type == .text {
                    // Check if we're in a text node within a list item
                    if let textNode = try? anchor.getNode() as? TextNode,
                       let listItem = findParentListItem(textNode) {
                        
                        // Check if we're at the beginning of the text and the list item only contains zero-width space
                        if anchor.offset == 0 {
                            shouldInterceptDeletion = isListItemOnlyZeroWidthSpace(listItem)
                        }
                    }
                }
            }
            
            // If we detected a zero-width space only list item, handle it specially
            if shouldInterceptDeletion {
                try editor.update {
                    guard let selection = try getSelection() as? RangeSelection else { return }
                    
                    // Find the list item to collapse
                    let anchor = selection.anchor
                    var listItemToCollapse: ListItemNode?
                    
                    if anchor.type == .element,
                       let anchorNode = try? anchor.getNode() as? ListItemNode {
                        listItemToCollapse = anchorNode
                    } else if anchor.type == .text,
                              let textNode = try? anchor.getNode() as? TextNode {
                        listItemToCollapse = findParentListItem(textNode)
                    }
                    
                    // Trigger the collapse behavior directly
                    if let listItem = listItemToCollapse {
                        _ = try listItem.collapseAtStart(selection: selection)
                    }
                }
                
                // Notify about selection changes
                editor.dispatchCommand(type: .selectionChange)
                return true // Command handled
            }
            
        } catch {
            print("Error in ZeroWidthSpaceFixPlugin: \(error)")
        }
        
        return false // Let default handler process the command
    }
    
    /// Checks if a list item contains only zero-width space characters
    private func isListItemOnlyZeroWidthSpace(_ listItem: ListItemNode) -> Bool {
        let children = listItem.getChildren()
        
        // If there are no children, it's empty
        if children.isEmpty {
            return true
        }
        
        // Check if all children are text nodes containing only zero-width space
        for child in children {
            if let textNode = child as? TextNode {
                let text = textNode.getTextContent()
                // Remove all zero-width space characters and check if anything remains
                let textWithoutZWS = text.replacingOccurrences(of: "\u{200B}", with: "")
                if !textWithoutZWS.isEmpty {
                    return false
                }
            } else {
                // If there's a non-text node, it's not "only zero-width space"
                return false
            }
        }
        
        return true
    }
    
    /// Finds the parent ListItemNode for a given node
    private func findParentListItem(_ node: Node) -> ListItemNode? {
        var currentNode: Node? = node
        
        while let node = currentNode {
            if let listItem = node as? ListItemNode {
                return listItem
            }
            currentNode = node.getParent()
        }
        
        return nil
    }
}