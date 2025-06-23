//
//  ContentView.swift
//  MarkdownEditor
//
//  Created by Juan Carlos on 6/21/25.
//

import SwiftUI
import MarkdownEditor

struct ContentView: View {
    var body: some View {
        TabView {
            // Legacy API Demo
            MarkdownEditorDemo()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Legacy API")
                }
            
            // Modern API Demo
            ModernAPIDemo()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Modern API")
                }
        }
    }
}

#Preview {
    ContentView()
}
