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
    @FocusState private var textFieldFocused: Bool
    @Environment(KHAccess.self) private var khAccess
    let backupper = Backupper()

    var body: some View {
        Form {
            // Probably not quite right on iOS
            Section("Load backup") {
                if backupper.list().isEmpty {
                    Text("No stored backups").foregroundColor(.secondary)
                } else {
                    Picker("Choose backup", selection: $selection) {
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
            }

            Section("New backup") {
                TextField("Name", text: $newName)
                    .textFieldStyle(.automatic)
                    .focused($textFieldFocused)
                Button("Save backup") {
                    Task {
                        // TODO better: Load parameters from state.
                        await khAccess.fetchParameterTree()
                        try backupper.write(name: newName, khAccess: khAccess)
                        selection = newName
                        newName = ""
                        textFieldFocused = false
                    }
                }
            }
        }
    }
}

struct BackupViewMacOS: View {
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess
    let backupper = Backupper()

    var body: some View {
        Form {
            if backupper.list().isEmpty {
                Text("No stored backups").foregroundColor(.secondary)
            } else {
                Picker("Load backup", selection: $selection) {
                    ForEach(backupper.list(), id: \.self) {
                        Label($0, systemImage: "text.document").tag($0)
                    }
                }
                .pickerStyle(.inline)
                HStack {
                    Button("Load") {
                        guard let selection else { return }
                        Task {
                            try await backupper.load(
                                name: selection,
                                khAccess: khAccess
                            )
                        }
                    }
                    Button("Delete", systemImage: "trash") {
                        guard let s = selection else { return }
                        do { try backupper.delete(name: s) } catch { print(error) }
                        selection = nil
                    }
                }
            }

            TextField("New backup", text: $newName)

            Button("Create") {
                Task {
                    // TODO better: Load parameters from state.
                    await khAccess.fetchParameterTree()
                    try backupper.write(name: newName, khAccess: khAccess)
                    selection = newName
                    newName = ""
                }
            }
        }
    }
}
