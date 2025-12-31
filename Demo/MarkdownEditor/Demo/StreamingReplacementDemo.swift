import SwiftUI

final class StreamingReplacementDemoProxy: ObservableObject {
    var onStream: (@MainActor () -> Void)?
    var onExport: (@MainActor () -> Void)?
}

struct StreamingReplacementDemo: View {
    @StateObject private var proxy = StreamingReplacementDemoProxy()

    var body: some View {
        StreamingReplacementDemoControllerRepresentable(proxy: proxy)
            .navigationTitle("Streaming Replacement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Stream") { proxy.onStream?() }
                    Button("Export") { proxy.onExport?() }
                }
            }
    }
}

private struct StreamingReplacementDemoControllerRepresentable: UIViewControllerRepresentable {
    let proxy: StreamingReplacementDemoProxy

    func makeUIViewController(context: Context) -> StreamingReplacementDemoViewController {
        let vc = StreamingReplacementDemoViewController()
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: StreamingReplacementDemoViewController, context: Context) {
        // No-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(proxy: proxy)
    }

    final class Coordinator {
        weak var controller: StreamingReplacementDemoViewController? {
            didSet {
                proxy.onStream = { [weak controller] in controller?.triggerStream() }
                proxy.onExport = { [weak controller] in controller?.triggerExport() }
            }
        }

        private let proxy: StreamingReplacementDemoProxy

        init(proxy: StreamingReplacementDemoProxy) {
            self.proxy = proxy
        }
    }
}

#Preview {
    NavigationView {
        StreamingReplacementDemo()
    }
}

