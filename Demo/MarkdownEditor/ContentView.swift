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
                
                // SwiftUI API Demo
                APIDemo()
                    .tabItem {
                        Image(systemName: "doc.text.fill")
                        Text("SwiftUI API")
                    }
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
