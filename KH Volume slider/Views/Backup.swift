//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct Backupper: View {
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess
    let backupsDir: URL = URL.documentsDirectory.appending(path: "backups")

    enum BackupperErrors: Error {
        case error(String)
    }

    init() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: backupsDir.path) {
            do {
                try fileManager.createDirectory(
                    at: backupsDir,
                    withIntermediateDirectories: false
                )
            } catch {
                print(error)
            }
        }
    }

    func decodeBackup(from data: Data) throws -> JSONData {
        var schemaDict = [KHDevice.ID: JSONData]()
        khAccess.devices.forEach { device in
            schemaDict[device.id] = JSONData(fromNodeTree: device.parameterTree)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(
            JSONData.self,
            from: data,
            configuration: JSONData.object(schemaDict)
        )
    }

    func writeBackup(name: String) throws {
        var newBackupDict = [String: JSONData]()
        khAccess.devices.forEach { device in
            newBackupDict[device.id] = JSONData(fromNodeTree: device.parameterTree)
        }
        let newBackup = JSONData.object(newBackupDict)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let backupData = try encoder.encode(newBackup)
        let fileManager = FileManager.default
        fileManager.createFile(
            atPath: backupsDir.appending(component: name + ".json").path(),
            contents: backupData
        )
    }

    func loadBackup(name: String) async throws {
        let fm = FileManager.default
        guard
            let backupData = fm.contents(
                atPath: backupsDir.appending(component: name).path()
            )
        else {
            throw BackupperErrors.error("Backup does not exist")
        }
        let backup = try decodeBackup(from: backupData)
        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                try device.parameterTree.load(from: deviceBackup)
            }
        }
        await khAccess.sendParameters()
        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                guard let newState = KHState(from: deviceBackup) else {
                    throw BackupperErrors.error(
                        "backed up JSONData not compatibe with state."
                    )
                }
                device.state = newState
            }
        }
        khAccess.state = khAccess.devices.first!.state
    }

    func deleteBackup(name: String) throws {
        let fm = FileManager.default
        try fm.trashItem(at: backupsDir.appending(path: name), resultingItemURL: nil)
    }

    func backupList() -> [String] {
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(
                at: backupsDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return urls.map(\.lastPathComponent)
        } catch {
            return ["Error loading list: " + String(describing: error)]
        }
    }

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
                if backupList().isEmpty {
                    Section("Backup list") {
                        Text("No backups").foregroundColor(.secondary)
                    }
                } else {
                    Picker("Backup list", selection: $selection) {
                        ForEach(backupList(), id: \.self) {
                            Label($0, systemImage: "text.document").tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                    Button("Load") {
                        if let selection {
                            Task { try await loadBackup(name: selection) }
                        }
                    }
                    Button("Delete", systemImage: "trash") {
                        if let s = selection {
                            do { try deleteBackup(name: s) } catch { print(error) }
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
                            try writeBackup(name: newName)
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
