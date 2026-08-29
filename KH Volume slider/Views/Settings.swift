//
//  Settings.swift
//  KH Volume slider
//
//  Created by Leander Blume on 28.08.26.
//

import SwiftUI

struct DeviceRow: Identifiable, Equatable {
    let id = UUID()
    var ip6: String = ""
}

struct SettingsView: View {
    var stateManager: StateManager
    @AppStorage("autoDiscover") var autoDiscover: Bool = true
    @AppStorage("staticIp6s") var staticIp6s: String = ""
    @State private var staticIp6sArray: [DeviceRow] = []

    private func loadFromStorage() {
        let strings = staticIp6s.split(separator: ",").map(String.init)
        staticIp6sArray = strings.map { DeviceRow(ip6: $0) }
    }

    private func updateStorage() {
        staticIp6s = staticIp6sArray.map(\.ip6).joined(separator: ",")
    }

    var body: some View {
        Form {
            Toggle("Bonjour discovery", isOn: $autoDiscover)

            Group {
                List($staticIp6sArray) { $d in
                    HStack {
                        TextField("IPv6", text: $d.ip6)
                            .disableAutocorrection(true)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif

                        Button {
                            staticIp6sArray.removeAll { $0.id == d.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .onChange(of: staticIp6sArray, updateStorage)

                Button("Add device") {
                    staticIp6sArray.append(DeviceRow())
                }
            }
            .disabled(autoDiscover)

            BackupView(stateManager: stateManager)
        }
        .onAppear(perform: loadFromStorage)
    }
}
