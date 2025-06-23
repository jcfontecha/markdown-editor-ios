import SwiftUI
import UIKit
import MarkdownEditor

// MARK: - SwiftUI Integration

struct MarkdownEditorDemo: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let demoViewController = DemoViewController()
        let navigationController = UINavigationController(rootViewController: demoViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed for this demo
    }
}

// MARK: - Preview

#Preview {
    MarkdownEditorDemo()
}