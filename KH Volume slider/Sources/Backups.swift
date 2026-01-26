//
//  Backups.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.01.26.
//

import Foundation

@MainActor
protocol SchemaCacheProtocol {
    init()

    func getSchema(for device: KHDevice) throws -> JSONDataCodable?
    func saveSchema(of device: KHDevice) throws
}

struct SchemaCache: SchemaCacheProtocol {
    let deviceSchemata: URL = URL.documentsDirectory.appending(
        component: "device_schemata.json"
    )

    private struct DeviceModelID: Codable, Hashable {
        let product: String
        let version: String
        
        init(_ state: KHState) {
            product = state.product
            version = state.version
        }
    }

    private typealias SchemaList = [DeviceModelID: JSONDataCodable]

    init() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: deviceSchemata.path) {
            do {
                let emptyList = try JSONEncoder().encode(SchemaList())
                fileManager.createFile(
                    atPath: deviceSchemata.path(),
                    contents: emptyList
                )
            } catch {
                print(error)
            }
        }
    }

    private enum PresetManagerErrors: Error {
        case error(String)
    }

    private func getSchemaList() throws -> SchemaList {
        let data = try Data(contentsOf: deviceSchemata)
        return try JSONDecoder().decode(SchemaList.self, from: data)
    }

    private func writeSchemaList(_ schemaList: SchemaList) throws {
        let data = try JSONEncoder().encode(schemaList)
        try data.write(to: deviceSchemata)
    }

    func getSchema(for device: KHDevice) throws -> JSONDataCodable? {
        let schemaList = try getSchemaList()
        return schemaList[DeviceModelID(device.state)]
    }

    func saveSchema(of device: KHDevice) throws {
        let jdc = JSONDataCodable(fromNodeTree: device.parameterTree)
        var schemaList = try getSchemaList()
        schemaList[DeviceModelID(device.state)] = jdc
        try writeSchemaList(schemaList)
    }
}

struct Backupper {
    let backupsDir: URL = URL.documentsDirectory.appending(path: "backups")

    // currently unused, maybe in the future.
    private struct DeviceIdentifier: Codable, Hashable {
        let model: String
        let version: String
        let serial: String
    }

    private typealias Backup = [KHDevice.ID: JSONDataCodable]

    private enum BackupperErrors: Error {
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
                try device.parameterTree.load(jsonDataCodable: deviceBackup)
                guard let newState = KHState(jsonDataCodable: deviceBackup) else {
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
