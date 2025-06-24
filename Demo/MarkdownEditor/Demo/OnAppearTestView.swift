import SwiftUI
import MarkdownEditor

@available(iOS 17.0, *)
struct OnAppearTestView: View {
    // This mimics exactly what we're doing in the Vidnote app
    @State private var markdownContent: String = ""
    
    // Simulate note content that would come from a model
    let simulatedNoteContent = "# Test\nGgg today"
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Testing MarkdownEditor with onAppear")
                    .font(.headline)
                    .padding()
                
                Text("Content: '\(markdownContent)'")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                
                // This is exactly how we use it in NoteDetailView
                MarkdownEditor(
                    text: $markdownContent,
                    configuration: .default
                        .theme(.default)
                        .features(.standard),
                    placeholderText: "No content available"
                )
                .padding()
                .ignoresSafeArea(.keyboard)
                
                Spacer()
            }
            .navigationTitle("OnAppear Test")
            .onAppear {
                // This mimics loading content in onAppear like we do
                markdownContent = simulatedNoteContent
                print("🔍 Set markdownContent in onAppear to: '\(markdownContent)'")
            }
        }
    }
}

// Also test with init approach
@available(iOS 17.0, *)
struct InitTestView: View {
    @State private var markdownContent: String
    
    init(content: String) {
        self._markdownContent = State(initialValue: content)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Testing MarkdownEditor with init")
                    .font(.headline)
                    .padding()
                
                Text("Content: '\(markdownContent)'")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                
                MarkdownEditor(
                    text: $markdownContent,
                    configuration: .default
                        .theme(.default)
                        .features(.standard),
                    placeholderText: "No content available"
                )
                .padding()
                
                Spacer()
            }
            .navigationTitle("Init Test")
        }
    }
}