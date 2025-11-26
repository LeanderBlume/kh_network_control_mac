//
//  Settings.swift
//  KH Volume slider
//
//  Created by Leander Blume on 23.01.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("volumePath") private var volumePath = "/audio/out/level"
    @AppStorage("mutePath") private var mutePath = "/audio/out/mute"
    @AppStorage("logoBrightnessPath") private var logoBrightnessPath = "/ui/logo/brightness"

    public var body: some View {
        VStack {
            Form {
                Section(header: Text("SSC parameter paths")) {
                    LabeledContent {
                        TextField("Volume", text: $volumePath)
                    } label: {
                        Text("Volume:")
                    }
                    TextField("Mute", text: $mutePath)
                    TextField("Logo brightness", text: $logoBrightnessPath)
                }
            }
        }
        .scenePadding()
        .frame(width: 350)
    }
}

#Preview {
    SettingsView()
}
