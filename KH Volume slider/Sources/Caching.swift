//
//  Backups.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.01.26.
//

import Foundation

protocol PlainInitializable {
    init()
}

extension Array: PlainInitializable {}
extension Dictionary: PlainInitializable {}

protocol SingleFileAccess {
    static var fileURL: URL { get }
    associatedtype FileSchema: Codable, PlainInitializable
    init() throws
    static func ensureFileExists() throws
    func getFileContents() throws -> FileSchema
    func writeFile(_ contents: FileSchema, prettyPrinted: Bool) throws
    func clear() throws
}

extension SingleFileAccess {
    static func ensureFileExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Self.fileURL.path) {
            let emptyList = try JSONEncoder().encode(FileSchema())
            fileManager.createFile(atPath: Self.fileURL.path(), contents: emptyList)
        }
    }

    func getFileContents() throws -> FileSchema {
        let data = try Data(contentsOf: Self.fileURL)
        return try JSONDecoder().decode(FileSchema.self, from: data)
    }

    func writeFile(_ contents: FileSchema, prettyPrinted: Bool = false) throws {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        }
        let data = try encoder.encode(contents)
        try data.write(to: Self.fileURL)
    }
    
    func clear() throws {
        try writeFile(FileSchema())
    }
}

protocol ConnectionCacheProtocol: SingleFileAccess {
    func getConnections() throws -> [SSCConnection]
    func saveConnections(_ connections: [SSCConnection]) async throws
}

protocol SchemaCacheProtocol: SingleFileAccess {
    @MainActor func getSchema(for device: KHDevice) throws -> DeviceSchema?
    @MainActor func saveSchema(_: SSCNode, for device: KHDevice) throws
}

protocol StateCacheProtocol: SingleFileAccess {
    @MainActor func getState(for device: KHDevice) throws -> (KHState, JSONDataCodable)?
    @MainActor func saveState(for device: KHDevice) throws
}

// This one is different. It manages multiple files.
protocol BackupperProtocol {
    func delete(name: String) throws
    func list() -> [String]
    @MainActor func write(name: String, khAccess: KHAccess) throws
    @MainActor func load(name: String, khAccess: KHAccess) async throws
}

struct ConnectionCache: ConnectionCacheProtocol {
    static let fileURL: URL = URL.documentsDirectory.appending(
        component: "connections.json"
    )

    init() throws {
        try Self.ensureFileExists()
    }

    struct BonjourService: Codable {
        let name: String
        let type: String
        let domain: String
    }

    typealias FileSchema = [BonjourService]

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
}

struct SchemaCache: SchemaCacheProtocol {
    static let fileURL: URL = URL.documentsDirectory.appending(
        component: "device_schemata.json"
    )

    init() throws {
        try Self.ensureFileExists()
    }

    struct DeviceModelID: Codable, Hashable {
        let product: String
        let version: String

        init(_ state: KHState) {
            product = state.product
            version = state.version
        }
    }

    typealias FileSchema = [DeviceModelID: DeviceSchema]

    @MainActor
    func getSchema(for device: KHDevice) throws -> DeviceSchema? {
        let schemaList = try getFileContents()
        return schemaList[DeviceModelID(device.state)]
    }

    @MainActor
    func saveSchema(_ rootNode: SSCNode, for device: KHDevice) throws {
        let jdc = DeviceSchema(from: rootNode)
        var schemaList = try getFileContents()
        schemaList[DeviceModelID(device.state)] = jdc
        try writeFile(schemaList, prettyPrinted: true)
    }
}

struct StateCache: StateCacheProtocol {
    static let fileURL = URL.documentsDirectory.appendingPathComponent("cache.json")

    init() throws {
        try Self.ensureFileExists()
    }

    typealias FileSchema = [KHDevice.ID: JSONDataCodable]

    private enum StateCacheError: Error {
        case error(String)
    }

    @MainActor
    func getState(for device: KHDevice) throws -> (KHState, JSONDataCodable)? {
        let list = try getFileContents()
        guard let jdc = list[device.id] else { return nil }
        guard let state = KHState(jsonDataCodable: jdc) else {
            throw StateCacheError.error("JSON Data to State conversion error")
        }
        return (state, jdc)
    }

    @MainActor
    func saveState(for device: KHDevice) throws {
        guard let rootNode = device.parameterTree else {
            throw StateCacheError.error("Parameters not populated")
        }
        guard let jdc = JSONDataCodable(from: rootNode) else {
            throw StateCacheError.error("Parameter tree to JSON Conversion failed")
        }
        var contents = try getFileContents()
        contents[device.id] = jdc
        try writeFile(contents)
    }
}

struct Backupper: BackupperProtocol {
    private static let backupsDir: URL = URL.documentsDirectory.appending(
        path: "backups/"
    )

    static func ensureFileExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Self.backupsDir.path) {
            try fileManager.createDirectory(
                at: Self.backupsDir,
                withIntermediateDirectories: false
            )
        }
    }

    init() throws {
        try Self.ensureFileExists()
    }

    private typealias FileSchema = [KHDevice.ID: JSONDataCodable]

    private enum BackupperErrors: Error {
        case error(String)
    }

    private func decode(from data: Data) throws -> FileSchema {
        return try JSONDecoder().decode(FileSchema.self, from: data)
    }

    private func getBackup(name: String) throws -> FileSchema {
        let fm = FileManager.default
        guard
            let backupData = fm.contents(
                atPath: Self.backupsDir.appending(component: name).path(
                    percentEncoded: false
                )
            )
        else {
            throw BackupperErrors.error("Backup does not exist")
        }
        return try decode(from: backupData)
    }

    private func saveBackup(name: String, backup: FileSchema) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let backupData = try encoder.encode(backup)
        let url = URL(filePath: name + ".json", relativeTo: Self.backupsDir)
        FileManager.default.createFile(
            atPath: url.path(percentEncoded: false),
            contents: backupData
        )
    }

    func delete(name: String) throws {
        let fm = FileManager.default
        try fm.trashItem(
            at: Self.backupsDir.appending(path: name),
            resultingItemURL: nil
        )
    }

    func list() -> [String] {
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(
                at: Self.backupsDir,
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
        var newBackup = FileSchema()

        for device in khAccess.devices {
            guard let rootNode = device.parameterTree else {
                throw BackupperErrors.error(
                    "Could not write backup, parameters not loaded."
                )
            }
            guard let jsonData = JSONData(from: rootNode) else {
                throw BackupperErrors.error(
                    "Could not write backup, JSONData conversion failed."
                )
            }
            newBackup[device.id] = JSONDataCodable(from: jsonData)
        }

        try saveBackup(name: name, backup: newBackup)
    }

    @MainActor
    func load(name: String, khAccess: KHAccess) async throws {
        let backup = try getBackup(name: name)

        try khAccess.devices.forEach { device in
            if let deviceBackup = backup[device.id] {
                guard let rootNode = device.parameterTree else { return }
                try rootNode.load(from: deviceBackup)
                guard let newState = KHState(jsonDataCodable: deviceBackup) else {
                    throw BackupperErrors.error(
                        "backed up JSONData not compatibe with state."
                    )
                }
                device.state = newState
            }
        }
        await khAccess.sendParameterTree()
        khAccess.state = khAccess.devices.first!.state
    }
}
