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
        if #available(iOS 17.0, *) {
            TabView {
                // UIKit API Demo
                MarkdownEditorDemo()
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("UIKit API")
                    }
                    .ignoresSafeArea()
                
                // SwiftUI API Demo
                APIDemo()
                    .tabItem {
                        Image(systemName: "doc.text.fill")
                        Text("SwiftUI API")
                    }
                    .ignoresSafeArea()
                
                // Editing State Demo
                EditingStateDemo()
                    .tabItem {
                        Image(systemName: "pencil.circle")
                        Text("Editing State")
                    }
                    .ignoresSafeArea()
                
            }
        } else {
            MarkdownEditorDemo()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
