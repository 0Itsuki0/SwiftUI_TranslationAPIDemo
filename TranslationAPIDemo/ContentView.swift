//
//  ContentView.swift
//  TranslationAPIDemo
//
//  Created by Itsuki on 2026/01/05.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("On Device Translation")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                    .frame(height: 8)
                NavigationLink(destination: {
                    SystemTranslationUIDemo()
                }, label: {
                    Text("System UI")
                        .padding(.vertical, 4)
                })
                
                NavigationLink(destination: {
                    CustomTranslationDemo()
                }, label: {
                    Text("Custom")
                        .padding(.vertical, 4)
                })
            }
            .fontWeight(.semibold)
            .buttonSizing(.flexible)
            .buttonStyle(.borderedProminent)
            .padding(.all, 48)
            .navigationTitle("Translation API")
            .navigationBarTitleDisplayMode(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.yellow.opacity(0.1))
        }
    }
}

#Preview {
    ContentView()
}
