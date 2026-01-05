//
//  SystemTranslation.swift
//  TranslationAPIDemo
//
//  Created by Itsuki on 2026/01/05.
//

import SwiftUI
import Translation

struct SystemTranslationUIDemo: View {
    
    @State private var showTranslationSheet = false
    @State private var translatedText: String? = nil

    private let text = "I love pikachu"

    var body: some View {
        List {
            Section {
                Text("""
                - Showing the System Translation UI with `translationPresentation`
                - Will work on simulators
                """)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
            }
            
            
            Section("Original") {
                Text(verbatim: text)
                
                Button(action: {
                    showTranslationSheet = true
                }, label: {
                    Text("Translate")
                })
                .translationPresentation(isPresented: $showTranslationSheet, text: text, replacementAction: {
                    self.translatedText = $0
                })
            }
            
            if let translatedText {
                Section("Translated") {
                    Text(verbatim: translatedText)
                }
            }
        }
        .navigationTitle("System UI")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SystemTranslationUIDemo()
    }
}
