//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct Backupper: View {
    @AppStorage("backups") private var backups = Data()  // [String: [String: JSONData]]
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess

    enum BackupperErrors: Error {
        case error(String)
    }

    func writeBackup(name: String) throws {
        var backupDict = try JSONDecoder().decode(
            [String: [String: JSONData]].self,
            from: Data(backups)
        )
        var newBackup = [String: JSONData]()
        khAccess.devices.forEach { device in
            newBackup[device.id] = JSONData(fromNodeTree: device.parameterTree)
        }
        // backupDict[name] = khAccess.state
        guard let newBackupData = try? JSONEncoder().encode(backupDict) else {
            throw BackupperErrors.error("JSON Encoding failed")
        }
        backups = newBackupData
    }

    func loadBackup(name: String) throws {
        let backupString = backups
        let backupDict = try JSONDecoder().decode(
            [String: KHState].self,
            from: Data(backupString.utf8)
        )
        guard let newState = backupDict[name] else {
            throw BackupperErrors.error("No such backup")
        }
        khAccess.state = newState
    }

    func deleteBackup(name: String) throws {
        let backupString = backups
        var backupDict = try JSONDecoder().decode(
            [String: KHState].self,
            from: Data(backupString.utf8)
        )
        backupDict[name] = nil
        let newBackupData = try JSONEncoder().encode(backupDict)
        guard let newBackupString = String(data: newBackupData, encoding: .utf8) else {
            throw BackupperErrors.error("String conversion failed")
        }
        backups = newBackupString
    }

    func backupList() -> [String] {
        let backupString = backups
        guard
            let backupDict = try? JSONDecoder().decode(
                [String: KHState].self,
                from: Data(backupString.utf8)
            )
        else {
            return ["FAIL"]
        }
        return backupDict.keys.map({ String($0) }).sorted()
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
            Button("Delete all") {
                backups = "{}"
            }
            Button("Print full backup") {
                let jd = JSONData(fromNodeTree: khAccess.devices[0].parameterTree)
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
