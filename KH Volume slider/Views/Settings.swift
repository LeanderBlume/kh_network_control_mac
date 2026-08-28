//
//  Settings.swift
//  KH Volume slider
//
//  Created by Leander Blume on 28.08.26.
//

import SwiftUI

struct SettingsView: View {
    var stateManager: StateManager
    @AppStorage("autoDiscover") var autoDiscover: Bool = true
    @AppStorage("staticIp6s") var staticIp6s: String = ""
    @State private var staticIp6sArray: [String] = []
    
    private func loadFromStorage() {
        staticIp6sArray = staticIp6s.split(separator: ",").map(String.init)
    }
    
    private func updateStorage() {
        staticIp6s = staticIp6sArray.joined(separator: ",")
    }
    
    var body: some View {
        VStack {
            Form {
                Toggle("Auto discover", isOn: $autoDiscover)
                
                Group {
                    List(staticIp6sArray.indices, id: \.self) { i in
                        TextField("IPv6 \(i + 1)", text: $staticIp6sArray[i])
                    }
                    .onChange(of: staticIp6sArray, updateStorage)
                    
                    Button("Add device") {
                        staticIp6sArray.append("")
                    }
                    Button("Test") {
                        print(staticIp6sArray)
                        print(staticIp6s)
                    }
                }
                .disabled(autoDiscover)
            }

            BackupView(stateManager: stateManager)
        }
        .onAppear(perform: loadFromStorage)
    }
}
