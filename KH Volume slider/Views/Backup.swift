//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct Backupper: View {
    @AppStorage("backups") private var backups = Data()
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess

    typealias BackupFormat = [KHDevice.ID: JSONData]
    typealias BackupListFormat = [String: BackupFormat]

    enum BackupperErrors: Error {
        case error(String)
    }

    func writeBackup(name: String) throws {
        var newBackup = BackupFormat()
        khAccess.devices.forEach { device in
            newBackup[device.id] = JSONData(fromNodeTree: device.parameterTree)
        }
        var backupDict = try JSONDecoder().decode(
            BackupListFormat.self,
            from: Data(backups)
        )
        backupDict[name] = newBackup
        backups = try JSONEncoder().encode(backupDict)
    }

    func loadBackup(name: String) throws {
        let backupDict = try JSONDecoder().decode(
            BackupListFormat.self,
            from: backups
        )
        guard let backup = backupDict[name] else {
            throw BackupperErrors.error("No such backup")
        }
        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                try device.parameterTree.load(from: deviceBackup)
                device.state = try KHState(from: deviceBackup)
            }
        }
        khAccess.state = khAccess.devices.first!.state
    }

    func deleteBackup(name: String) throws {
        var backupDict = try JSONDecoder().decode(
            BackupFormat.self,
            from: backups
        )
        backupDict[name] = nil
        backups = try JSONEncoder().encode(backupDict)
    }

    func backupList() -> [String] {
        do {
            let decoder = JSONDecoder()
            let backupDict = try decoder.decode(
                BackupListFormat.self,
                from: backups
            )
            return backupDict.keys.sorted()
        } catch {
            return [String(describing: error)]
        }
    }

    var body: some View {
        Form {
            Picker("Backup list", selection: $selection) {
                ForEach(backupList(), id: \.self) {
                    Text($0).tag($0)
                }
            }
            .pickerStyle(.inline)

            Button("Load") {
                if let selection {
                    Task {
                        try loadBackup(name: selection)
                        await khAccess.send()
                    }
                }
            }
            Button("Delete") {
                if let s = selection {
                    Task { try deleteBackup(name: s) }
                    selection = nil
                }
            }
            Button("Reset") {
                Task {
                    backups = try JSONEncoder().encode(BackupListFormat())
                }
            }
            Button("Print full backup") {
                let jd = try? JSONDecoder().decode(BackupListFormat.self, from: backups)
                if let jd {
                    print(jd)
                } else {
                    print("nil")
                }
            }

            Section("Create new backup") {
                TextField("Backup name", text: $newName)
                    .textFieldStyle(.automatic)
                Button("Save backup") {
                    Task {
                        try writeBackup(name: newName)
                        selection = newName
                        newName = ""
                    }
                }
            }
        }
    }
}
