//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI


struct BackupView: View {
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess
    let backupper = Backupper()

    var body: some View {
        let populated = khAccess.devices.first?.parameterTree.value.isUnknown() == false
        Form {
            if !populated {
                Text("Populate parameters to save and load backups")
                Button("Populate parameters") {
                    Task { await khAccess.populateParameters() }
                }
            }
            Group {
                if backupper.list().isEmpty {
                    Section("Backup list") {
                        Text("No backups").foregroundColor(.secondary)
                    }
                } else {
                    Picker("Backup list", selection: $selection) {
                        ForEach(backupper.list(), id: \.self) {
                            Label($0, systemImage: "text.document").tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                    Button("Load") {
                        if let selection {
                            Task {
                                try await backupper.load(
                                    name: selection,
                                    khAccess: khAccess
                                )
                            }
                        }
                    }
                    Button("Delete", systemImage: "trash") {
                        if let s = selection {
                            do { try backupper.delete(name: s) } catch { print(error) }
                            selection = nil
                        }
                    }
                }

                Section("Create new backup") {
                    TextField("Backup name", text: $newName)
                        .textFieldStyle(.automatic)
                    Button("Save backup") {
                        Task {
                            // TODO better: Load parameters from state.
                            await khAccess.fetchParameters()
                            try backupper.write(name: newName, khAccess: khAccess)
                            selection = newName
                            newName = ""
                        }
                    }
                }
            }
            .disabled(!populated)
        }
    }
}
