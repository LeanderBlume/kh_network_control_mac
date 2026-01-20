//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct Backupper: View {
    @AppStorage("backups") private var backups = Data()
    // @AppStorage("backupNames") private var backupNames = Data() // [String]
    @State var newName: String = ""
    @State var selection: String? = nil
    @Environment(KHAccess.self) private var khAccess

    typealias BackupFormat = [KHDevice.ID: JSONData]
    typealias BackupListFormat = [String: BackupFormat]

    enum BackupperErrors: Error {
        case error(String)
    }

    func decodeBackup() throws -> BackupListFormat {
        let decoder = JSONDecoder()
        // not as simple as I thought!
        let schemata = khAccess.devices.map {
            JSONData(fromNodeTree: $0.parameterTree)
        }
        return try decoder.decode(BackupListFormat.self, from: backups)
    }

    func writeBackup(name: String) throws {
        var newBackup = BackupFormat()
        khAccess.devices.forEach { device in
            newBackup[device.id] = JSONData(fromNodeTree: device.parameterTree)
        }
        var backupDict = try decodeBackup()
        backupDict[name] = newBackup
        backups = try JSONEncoder().encode(backupDict)
    }

    func loadBackup(name: String) throws {
        let backupDict = try decodeBackup()
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
        var backupDict = try decodeBackup()
        backupDict[name] = nil
        backups = try JSONEncoder().encode(backupDict)
    }

    func backupList() -> [String] {
        do {
            let backupDict = try decodeBackup()
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
                let jd = try? decodeBackup()
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
