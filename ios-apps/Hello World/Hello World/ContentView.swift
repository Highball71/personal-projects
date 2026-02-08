//
//  ContentView.swift
//  Hello World
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, David!")
                .font(.largeTitle)
            Text("Your dev environment is ready 🚀")
                .font(.title3)
        }        .padding()
    }
}

#Preview {
    ContentView()
}
