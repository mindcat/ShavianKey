//
//  ContentView.swift
//  ShavianKey
//
//  Created by koteczek on 10/22/25.
//

import SwiftUI


struct ContentView: View {
    @State private var test: String = ""
    var body: some View {
        VStack {
            HStack {
                Image("dict.check")
                Image("dict.plus")
                Image("dict.x")
            }
            Text("𐑣𐑧𐑤𐑴 𐑢𐑻𐑤𐑛!").font(.custom("InterAlia-Regular.ttf", size: 28))
            TextField("𐑦𐑯𐑐𐑫𐑑 𐑑𐑧𐑕𐑑𐑦𐑙 𐑑𐑧𐑒𐑕𐑑 𐑓𐑰𐑤𐑛...", text: $test)
            Text("𐑧𐑒𐑴: " + test)
        }
        .textFieldStyle(.roundedBorder)
        .padding()
    }
}

#Preview {
    ContentView()
}
