import SwiftUI
import UIKit

final class UIKitEditorDemoProxy: ObservableObject {
    var onStream: (@MainActor () -> Void)?
    var onExport: (@MainActor () -> Void)?
}

// MARK: - SwiftUI Integration

struct MarkdownEditorDemo: View {
    @StateObject private var proxy = UIKitEditorDemoProxy()

    var body: some View {
        DemoViewControllerRepresentable(proxy: proxy)
            .navigationTitle("Markdown Editor Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Stream") { proxy.onStream?() }
                    Button("Export") { proxy.onExport?() }
                }
            }
    }
}

private struct DemoViewControllerRepresentable: UIViewControllerRepresentable {
    let proxy: UIKitEditorDemoProxy

    func makeUIViewController(context: Context) -> DemoViewController {
        let vc = DemoViewController()
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: DemoViewController, context: Context) {
        // No-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(proxy: proxy)
    }

    final class Coordinator {
        weak var controller: DemoViewController? {
            didSet {
                proxy.onStream = { [weak controller] in controller?.triggerStream() }
                proxy.onExport = { [weak controller] in controller?.triggerExport() }
            }
        }

        private let proxy: UIKitEditorDemoProxy

        init(proxy: UIKitEditorDemoProxy) {
            self.proxy = proxy
        }
    }
}

#Preview {
    NavigationView {
        MarkdownEditorDemo()
    }
}
