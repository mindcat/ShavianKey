//
//  ContentView.swift
//  ShavianKey
//
//  Created by koteczek on 10/22/25.
//

import SwiftUI

private let appGroupID = "group.com.koteczek.ShavianKey"
private let sharedDefaults = UserDefaults(suiteName: appGroupID)!

struct ContentView: View {
    @State private var test: String = ""
    @AppStorage("proofing", store: sharedDefaults) var proofing: Bool = true
    @AppStorage("transliteration", store: sharedDefaults) var transliteration: Bool = true
    @AppStorage("left_delete", store: sharedDefaults) var left_delete: Bool = true
    
    @State private var displayLanguage: DisplayLanguage = .shavian
    
    @Environment(\.colorScheme) var colorScheme
        
    enum DisplayLanguage {
        case shavian
        case english
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(localizedString("𐑒𐑰𐑚𐑹𐑛 𐑕𐑧𐑑𐑦𐑙𐑟", "Keyboard Settings"))) {
                    Toggle(localizedString("𐑐𐑮𐑧𐑓𐑦𐑙 (·𐑖𐑷𐑝𐑾𐑯)", "Proofing (Shavian)"), isOn: $proofing)
                    Toggle(localizedString("𐑑𐑮𐑨𐑯𐑟𐑤𐑦𐑑𐑼𐑱𐑖𐑯 (QWERTY)", "Transliteration (QWERTY)"), isOn: $transliteration)
                    Toggle(localizedString("𐑛𐑦𐑤𐑰𐑑 𐑑 𐑞 𐑤𐑧𐑓𐑑 𐑝 𐑕𐑐𐑱𐑕", "Delete to the left of space"), isOn: $left_delete)
                }
     
                Section(header: Text(localizedString("𐑑𐑧𐑕𐑑 𐑨𐑕𐑧𐑑𐑕", "Test Assets"))) {
                    HStack {
                        colorScheme == .dark ? Image("translate.dark") : Image("translate")
                        colorScheme == .dark ? Image("dict.check.dark") : Image("dict.check")
                        colorScheme == .dark ? Image("dict.plus.dark") : Image("dict.plus")
                        colorScheme == .dark ? Image("dict.x.dark") : Image("dict.x")
                    }
                }
     
                Section(header: Text(localizedString("𐑐𐑤𐑱𐑜𐑮𐑬𐑯𐑛", "Playground"))) {
                    Text(localizedString("𐑣𐑧𐑤𐑴 𐑢𐑻𐑤𐑛!", "Hello world!"))
                        .font(.custom("InterAlia-Regular.ttf", size: 28))
                    
                    TextField(localizedString("𐑦𐑯𐑐𐑫𐑑 𐑑𐑧𐑕𐑑𐑦𐑙 𐑑𐑧𐑒𐑕𐑑 𐑓𐑰𐑤𐑛...", "Input testing text field..."), text: $test)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack(spacing: 0) {
                        Text(localizedString("𐑧𐑒𐑴: ", "Echo: "))
                        Text(test)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 15).fill(Color.white)) 
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        displayLanguage = (displayLanguage == .shavian) ? .english : .shavian
                    }) {
                        colorScheme == .dark ? Image("translate.dark") : Image("translate")
                    }
                }
            }
        }
    }
    
    private func localizedString(_ shavian: String, _ english: String) -> String {
        return displayLanguage == .shavian ? shavian : english
    }
}

#Preview {
    ContentView()
}
