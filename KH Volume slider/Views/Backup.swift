//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 03.01.26.
//

import SwiftUI

struct Backupper: View {
    @AppStorage("backups") private var backups = "{}"
    @Environment(KHAccess.self) private var khAccess

    enum BackuperErrors: Error {
        case error(String)
    }

    func writeBackup(name: String) throws {
        let backupString = backups
        var backupDict = try JSONDecoder().decode(
            [String: KHState].self,
            from: Data(backupString.utf8)
        )
        backupDict[name] = khAccess.state
        let newBackupData = try JSONEncoder().encode(backupDict)
        guard let newBackupString = String(data: newBackupData, encoding: .utf8) else {
            throw BackuperErrors.error("String conversion failed")
        }
        backups = newBackupString
    }

    func loadBackup(name: String) throws {
        let backupString = backups
        let backupDict = try JSONDecoder().decode(
            [String: KHState].self,
            from: Data(backupString.utf8)
        )
        guard let newState = backupDict[name] else {
            throw BackuperErrors.error("No such backup")
        }
        khAccess.state = newState
    }

    var body: some View {
        VStack {
            Button("Save backup") {
                Task {
                    try writeBackup(name: "test")
                }
            }
            Button("Load backup") {
                Task {
                    try loadBackup(name: "test")
                    await khAccess.send()
                }
            }
            Button("Print backup") {
                print(backups)
            }
        }
    }
}
