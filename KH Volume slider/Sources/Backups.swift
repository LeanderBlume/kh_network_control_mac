//
//  Backups.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.01.26.
//

import Foundation

protocol StateManagerType {
    init()

    func getSchema(for device: KHDevice) throws -> JSONDataCodable?
    func saveSchema(of device: KHDevice) throws
    func saveConnection(_ connection: SSCConnection) throws

}

struct PresetManager {
    let deviceSchemata: URL? = Bundle.main.url(
        forResource: "DeviceSchemata",
        withExtension: ".json"
    )

    enum PresetManagerErrors: Error {
        case error(String)
    }

    private func decode(from data: Data) throws -> [KHDevice.ID: JSONDataCodable] {
        return try JSONDecoder().decode(
            [KHDevice.ID: JSONDataCodable].self,
            from: data
        )
    }
}

struct Backupper {
    let backupsDir: URL = URL.documentsDirectory.appending(path: "backups")

    typealias Backup = [KHDevice.ID: JSONDataCodable]

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

    private func decode(from data: Data) throws -> Backup {
        return try JSONDecoder().decode(Backup.self, from: data)
    }

    private func getBackup(name: String) throws -> Backup {
        let fm = FileManager.default
        guard
            let backupData = fm.contents(
                atPath: backupsDir.appending(component: name).path()
            )
        else {
            throw BackupperErrors.error("Backup does not exist")
        }
        return try decode(from: backupData)
    }

    private func saveBackup(name: String, backup: Backup) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let backupData = try encoder.encode(backup)
        let fileManager = FileManager.default
        fileManager.createFile(
            atPath: backupsDir.appending(component: name + ".json").path(),
            contents: backupData
        )
    }

    func delete(name: String) throws {
        let fm = FileManager.default
        try fm.trashItem(at: backupsDir.appending(path: name), resultingItemURL: nil)
    }

    func list() -> [String] {
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

    @MainActor
    func write(name: String, khAccess: KHAccess) throws {
        var newBackup = Backup()
        khAccess.devices.forEach { device in
            if let jsonData = JSONData(fromNodeTree: device.parameterTree) {
                newBackup[device.id] = JSONDataCodable(jsonData: jsonData)
            }
        }

        try saveBackup(name: name, backup: newBackup)
    }

    @MainActor
    func load(name: String, khAccess: KHAccess) async throws {
        let backup = try getBackup(name: name)

        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                let jsonData = JSONData(jsonDataCodable: deviceBackup)
                try device.parameterTree.load(from: jsonData)
                guard let newState = KHState(from: jsonData) else {
                    throw BackupperErrors.error(
                        "backed up JSONData not compatibe with state."
                    )
                }
                device.state = newState
            }
        }
        await khAccess.sendParameters()
        khAccess.state = khAccess.devices.first!.state
    }
}
