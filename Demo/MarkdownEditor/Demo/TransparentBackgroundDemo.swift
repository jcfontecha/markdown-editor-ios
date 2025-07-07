import SwiftUI
import MarkdownEditor

// Example demonstrating transparent background usage for video overlay
@available(iOS 17.0, *)
struct TransparentBackgroundDemo: View {
    @State private var markdownText = """
    # Transparent Background Demo
    
    This editor demonstrates a **transparent background** that allows you to see the gradient behind it.
    
    ## Use Cases
    
    - Video overlays
    - Custom themed interfaces
    - Layered UI designs
    - Floating editors
    
    ## Features
    
    The transparent background is achieved by setting `backgroundColor: .clear` in the ColorTheme.
    
    > Notice how the gradient shows through the editor background!
    
    Try typing here to see how the transparent background works with your content.
    """
    
    var body: some View {
        NavigationView {
            ZStack {
                // Simulate video player background
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Markdown editor with transparent background
                MarkdownEditor(
                    text: $markdownText,
                    configuration: .default.theme(transparentTheme),
                    placeholderText: "Add notes..."
                )
            }
            .navigationTitle("Transparent Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Theme") {
                        Button("Transparent") {
                            // Already using transparent theme
                        }
                        Button("Semi-transparent") {
                            // Could switch to semi-transparent theme
                        }
                    }
                }
            }
        }
    }
    
    // Custom theme with transparent background
    private var transparentTheme: MarkdownTheme {
        MarkdownTheme(
            typography: .default,
            colors: ColorTheme(
                text: .white,
                accent: .systemBlue,
                code: .systemGray3,
                quote: .systemGray4,
                backgroundColor: .clear  // Transparent background
            ),
            spacing: .default
        )
    }
}

