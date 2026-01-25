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

    private func decode(from data: Data) throws -> [KHDevice.ID: JSONDataCodable] {
        return try JSONDecoder().decode(
            [KHDevice.ID: JSONDataCodable].self,
            from: data
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
        var newBackup = [String: JSONDataCodable]()
        khAccess.devices.forEach { device in
            if let jsonData = JSONData(fromNodeTree: device.parameterTree) {
                newBackup[device.id] = JSONDataCodable(jsonData: jsonData)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let backupData = try encoder.encode(newBackup)
        let fileManager = FileManager.default
        fileManager.createFile(
            atPath: backupsDir.appending(component: name + ".json").path(),
            contents: backupData
        )
    }

    @MainActor
    func load(name: String, khAccess: KHAccess) async throws {
        let fm = FileManager.default
        guard
            let backupData = fm.contents(
                atPath: backupsDir.appending(component: name).path()
            )
        else {
            throw BackupperErrors.error("Backup does not exist")
        }
        let backup = try decode(from: backupData)
        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                let jsonData = JSONData(jsonDataCodable: deviceBackup)
                try device.parameterTree.load(from: jsonData)
            }
        }
        await khAccess.sendParameters()
        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                let jsonData = JSONData(jsonDataCodable: deviceBackup)
                guard let newState = KHState(from: jsonData) else {
                    throw BackupperErrors.error(
                        "backed up JSONData not compatibe with state."
                    )
                }
                device.state = newState
            }
        }
        khAccess.state = khAccess.devices.first!.state
    }
}
