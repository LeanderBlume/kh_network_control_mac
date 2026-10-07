//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct BackupView: View {
    var stateManager: StateManager
    @State var newName: String = ""
    @State var selection: String? = nil
    @FocusState private var textFieldFocused: Bool
    @Environment(KHAccess.self) private var khAccess

    private func createBackup() async {
        // TODO better: Load parameters from state.
        await khAccess.fetchParameterTree()
        do {
            let backupper = try Backupper()
            try backupper.write(name: newName, khAccess: khAccess)
        } catch {
            print("Writing backup failed:", error)
            return
        }
        selection = newName
        newName = ""
        textFieldFocused = false
    }

    private func loadSelected() async {
        guard let selection else { return }
        do {
            let backupper = try Backupper()
            stateManager.deviceStates = try await backupper.load(
                name: selection,
                khAccess: khAccess
            )
        } catch {
            print("Loading backup failed:", error)
        }
    }

    private func deleteSelected() {
        guard let s = selection else { return }
        do {
            let backupper = try Backupper()
            try backupper.delete(name: s)
        } catch {
            print("Error deleting backup:", error)
        }
        selection = nil
    }

    private func backupList() -> [String] {
        guard let backupper = try? Backupper() else { return [] }
        return backupper.list()
    }

    var bodyiOS: some View {
        Group {
            Section("New backup") {
                TextField("Name", text: $newName)
                    .textFieldStyle(.automatic)
                    .focused($textFieldFocused)
                Button("Save") {
                    Task { await createBackup() }
                }
            }

            Section("Load backup") {
                if backupList().isEmpty {
                    Text("No stored backups").foregroundColor(.secondary)
                } else {
                    Picker("Choose backup", selection: $selection) {
                        ForEach(backupList(), id: \.self) {
                            Label($0, systemImage: "text.document").tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Button(
                        "Load",
                        systemImage:
                            "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    ) {
                        Task { await loadSelected() }
                    }

                    Button("Delete", systemImage: "trash", action: deleteSelected)

                }
            }
        }
    }

    var bodymacOS: some View {
        Form {
            TextField("New backup", text: $newName)

            Button("Create") {
                Task { await createBackup() }
            }

            Divider()

            if backupList().isEmpty {
                Text("No stored backups").foregroundColor(.secondary)
            } else {
                Picker("Load backup", selection: $selection) {
                    ForEach(backupList(), id: \.self) {
                        Label($0, systemImage: "text.document").tag($0)
                    }
                }
                .pickerStyle(.inline)
                HStack {
                    Button(
                        "Load",
                        systemImage:
                            "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    ) {
                        Task {
                            await loadSelected()
                        }
                    }
                    Button("Delete", systemImage: "trash", action: deleteSelected)
                }
            }
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}
