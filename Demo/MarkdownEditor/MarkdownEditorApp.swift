//
//  MarkdownEditorApp.swift
//  MarkdownEditor
//
//  Created by Juan Carlos on 6/21/25.
//

import SwiftUI

@main
struct MarkdownEditorApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                DemoListView()
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single view on all devices
            .ignoresSafeArea() // This is the key to prevent keyboard pushing content up!
        }
    }
}

struct DemoListView: View {
    var body: some View {
        List {
            Section("Markdown Editor Demos") {
                NavigationLink("UIKit API Demo") {
                    MarkdownEditorDemo()
                        .navigationBarTitleDisplayMode(.inline)
                        .ignoresSafeArea() // Critical for proper keyboard behavior
                }
                
                if #available(iOS 17.0, *) {
                    NavigationLink("SwiftUI API Demo") {
                        APIDemo()
                            .navigationBarTitleDisplayMode(.inline)
                            .ignoresSafeArea() // Critical for proper keyboard behavior
                    }
                }
            }
        }
        .navigationTitle("MarkdownEditor")
    }
}
