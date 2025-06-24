import SwiftUI
import UIKit
import MarkdownEditor

// MARK: - SwiftUI Integration

struct MarkdownEditorDemo: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> DemoViewController {
        let demoViewController = DemoViewController()
        return demoViewController
    }
    
    func updateUIViewController(_ uiViewController: DemoViewController, context: Context) {
        // No updates needed for this demo
    }
}

// MARK: - Preview

#Preview {
    MarkdownEditorDemo()
}
