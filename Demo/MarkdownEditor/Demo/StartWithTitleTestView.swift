import SwiftUI
import MarkdownEditor

@available(iOS 17.0, *)
struct StartWithTitleTestView: View {
    @State private var markdownText = ""
    
    var body: some View {
        NavigationView {
            MarkdownEditor(
                text: $markdownText,
                configuration: .default
                    .theme(.default)
                    .features(.standard)
                    .logging(LoggingConfiguration(
                        isEnabled: true,
                        level: .verbose,
                        includeTimestamps: true,
                        includeDetailedState: true
                    )),
                placeholderText: "Start typing..."
            )
            .navigationTitle("Start With Title Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        markdownText = ""
                    }
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}