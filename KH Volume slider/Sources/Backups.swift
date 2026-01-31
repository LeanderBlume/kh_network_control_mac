//
//  Backups.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.01.26.
//

import Foundation

protocol ConnectionCacheProtocol {
    init()

    func getConnections() throws -> [SSCConnection]
    func saveConnections(_ connections: [SSCConnection]) async throws
}

struct ConnectionCache: ConnectionCacheProtocol {
    let url: URL = URL.documentsDirectory.appending(component: "connections.json")

    private struct BonjourService: Codable {
        let name: String
        let type: String
        let domain: String
    }

    private typealias FileSchema = [BonjourService]  // Stores IPv6 addresses

    init() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                let emptyList = try JSONEncoder().encode(FileSchema())
                fileManager.createFile(atPath: url.path(), contents: emptyList)
            } catch {
                print(error)
            }
        }
    }

    private func getFileContents() throws -> FileSchema {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FileSchema.self, from: data)
    }

    private func writeFile(_ contents: FileSchema) throws {
        let data = try JSONEncoder().encode(contents)
        try data.write(to: url)
    }

    func getConnections() throws -> [SSCConnection] {
        let services = try getFileContents()
        var result = [SSCConnection]()
        services.forEach { service in
            result.append(
                .init(
                    serviceName: service.name,
                    type: service.type,
                    domain: service.domain
                )
            )
        }
        return result
    }

    func saveConnections(_ connections: [SSCConnection]) async throws {
        var result = FileSchema()
        for connection in connections {
            let service = await connection.service
            if let service {
                result.append(
                    BonjourService(name: service.0, type: service.1, domain: service.2)
                )
            }
        }
        try writeFile(result)
    }

    func clearConnections() async throws { try await saveConnections([]) }
}

@MainActor
protocol SchemaCacheProtocol {
    var url: URL { get }
    init()
    associatedtype FileSchema: Codable

    func getSchema(for device: KHDevice) throws -> JSONDataCodable?
    func saveSchema(_: SSCNode, for device: KHDevice) throws
}

struct SchemaCache: SchemaCacheProtocol {
    let url: URL = URL.documentsDirectory.appending(
        component: "device_schemata.json"
    )

    struct DeviceModelID: Codable, Hashable {
        let product: String
        let version: String

        init(_ state: KHState) {
            product = state.product
            version = state.version
        }
    }
    typealias FileSchema = [DeviceModelID: JSONDataCodable]

    init() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                let emptyList = try JSONEncoder().encode(FileSchema())
                fileManager.createFile(atPath: url.path(), contents: emptyList)
            } catch {
                print(error)
            }
        }
    }

    private func getSchemaList() throws -> FileSchema {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FileSchema.self, from: data)
    }

    private func writeSchemaList(_ schemaList: FileSchema) throws {
        let data = try JSONEncoder().encode(schemaList)
        try data.write(to: url)
    }

    func getSchema(for device: KHDevice) throws -> JSONDataCodable? {
        let schemaList = try getSchemaList()
        return schemaList[DeviceModelID(device.state)]
    }

    func saveSchema(_ rootNode: SSCNode, for device: KHDevice) throws {
        let jdc = JSONDataCodable(fromNodeTree: rootNode)
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
            guard let rootNode = device.parameterTree else { return }
            if let jsonData = JSONData(fromNodeTree: rootNode) {
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
                guard let rootNode = device.parameterTree else { return }
                try rootNode.load(jsonDataCodable: deviceBackup)
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
