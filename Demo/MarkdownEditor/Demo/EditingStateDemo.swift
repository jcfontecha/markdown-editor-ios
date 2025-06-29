import SwiftUI
import MarkdownEditor

@available(iOS 17.0, *)
struct EditingStateDemo: View {
    @State private var markdownText = """
    # Welcome to the Editing State Demo
    
    This demo shows how to track when the user is actively editing the markdown content.
    
    When you tap in the editor and the keyboard appears, you'll see Cancel and Save buttons appear in the navigation bar.
    
    ## Features
    
    - Automatic editing state detection
    - Cancel button to discard changes
    - Save button to persist changes
    - Clean UI that adapts to editing state
    
    Try editing this content to see the buttons appear!
    """
    
    @State private var isEditing = false
    @State private var savedText = ""
    @State private var showSaveAlert = false
    
    init() {
        _savedText = State(initialValue: markdownText)
    }
    
    var body: some View {
        NavigationView {
            MarkdownEditor(
                text: $markdownText,
                configuration: .default,
                placeholderText: "Start typing...",
                isEditing: $isEditing
            )
            .navigationTitle("Editing State Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            // Restore the saved text
                            markdownText = savedText
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            // Save the current text
                            savedText = markdownText
                            showSaveAlert = true
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Document Saved", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your markdown document has been saved successfully.")
            }
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    EditingStateDemo()
}