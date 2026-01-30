//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

import SwiftUI

@Observable
final class KHDevice: @MainActor KHDeviceProtocol {
    let connection: SSCConnection
    var state: KHState = KHState()
    var parameterTree: SSCNode? = nil

    struct KHDeviceID: Hashable, Codable {
        let name: String
        let serial: String
    }

    var id: KHDeviceID { .init(name: state.name, serial: state.serial) }

    enum KHDeviceError: Error {
        case error(String)
    }

    required init(connection: SSCConnection) { self.connection = connection }

    private func connect() async throws {
        try await connection.open()
    }

    private func disconnect() async {
        await connection.close()
    }

    func setup() async throws {
        try await connect()
        // We need to fetch product and version to identify the schema type.
        for p in KHParameters.setupParameters {
            state = try await p.fetch(into: state, connection: connection)
        }
        try await populateParameters()
        await disconnect()
        // We do NOT update the state now because that messes up the ID
    }

    func fetch() async throws {
        try await connect()
        for p in KHParameters.fetchParameters {
            state = try await p.fetch(into: state, connection: connection)
        }
        await disconnect()
    }

    func send(_ newState: KHState) async throws {
        if newState == state {
            // don't even connect
            return
        }
        try await connect()
        for p in KHParameters.sendParameters {
            try await p.send(
                oldState: state,
                newState: newState,
                connection: connection
            )
            state = p.copy(from: newState, into: state)
        }
        await disconnect()
    }

    func populateParameters() async throws {
        let rootNode = SSCNode(name: "root", deviceID: self.id, parent: nil)
        let schemaCache = SchemaCache()
        if let cachedSchema = try schemaCache.getSchema(for: self) {
            rootNode.populate(jsonDataCodable: cachedSchema)
            return
        }
        try await connect()
        try await rootNode.populate(connection: connection, recursive: true)
        await disconnect()
        try schemaCache.saveSchema(of: self)
        parameterTree = rootNode
    }

    func fetchParameters() async throws {
        guard let rootNode = parameterTree else { return }
        try await connect()
        for node in rootNode {
            if case .value = node.value {
                try await node.fetch(connection: connection)
            }
        }
        await disconnect()
    }

    func sendParameters() async throws {
        guard let rootNode = parameterTree else { return }
        try await connect()
        for node in rootNode {
            if case .value = node.value {
                try await node.send(connection: connection)
            }
        }
        await disconnect()
    }

    func sendNode(_ path: [String]) async throws {
        guard let rootNode = parameterTree else { return }
        guard let node = rootNode.getNodeByPath(path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await node.send(connection: connection)
        await disconnect()
    }

    func fetchNode(_ path: [String]) async throws {
        guard let rootNode = parameterTree else { return }
        guard let node = rootNode.getNodeByPath(path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await node.fetch(connection: connection)
        await disconnect()
    }
}
