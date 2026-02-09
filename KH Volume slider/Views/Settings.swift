//
//  Settings.swift
//  KH Volume slider
//
//  Created by Leander Blume on 23.01.25.
//

import SwiftUI

struct SettingsView: View {
    public var body: some View {
        VStack {
            Form {
                Section(header: Text("SSC parameter paths")) {
                    ForEach(KHParameters.allCases) { param in
                        let pathString =
                            "/"
                            + param.getKeyPath().devicePath.joined(separator: "/")
                        LabeledContent {
                            Text(pathString)
                        } label: {
                            Text(param.rawValue)
                        }
                    }
                }
            }
        }
        .frame(width: 350)
    }
}

#Preview {
    SettingsView()
}
