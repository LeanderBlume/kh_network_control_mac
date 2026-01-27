//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

import SwiftUI

@Observable
@MainActor
class KHDevice: @MainActor Identifiable {
    var state: KHState = KHState()
    let parameterTree: SSCNode
    let connection: SSCConnection
    var id: String { state.product + state.version + state.serial }

    enum KHDeviceError: Error {
        case error(String)
    }

    init(connection connection_: SSCConnection) {
        connection = connection_
        parameterTree = SSCNode(name: "root")
    }

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
        let schemaCache = SchemaCache()
        if let cachedSchema = try schemaCache.getSchema(for: self) {
            parameterTree.populate(jsonDataCodable: cachedSchema)
            return
        }
        try await connect()
        try await parameterTree.populate(connection: connection, recursive: true)
        await disconnect()
        try schemaCache.saveSchema(of: self)

    }

    func fetchParameters() async throws {
        try await connect()
        for node in parameterTree {
            if case .value = node.value {
                try await node.fetch(connection: connection)
            }
        }
        await disconnect()
    }

    func sendParameters() async throws {
        try await connect()
        for node in parameterTree {
            if case .value = node.value {
                try await node.send(connection: connection)
            }
        }
        await disconnect()
    }

    private func getNode(atPath path: [String]) -> SSCNode? {
        var node: SSCNode? = parameterTree
        for p in path {
            node = node![p]
            if node == nil {
                return nil
            }
        }
        return node
    }

    func sendNode(_ path: [String]) async throws {
        guard let node = getNode(atPath: path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await node.send(connection: connection)
        await disconnect()
    }

    func fetchNode(_ path: [String]) async throws {
        guard let node = getNode(atPath: path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await node.fetch(connection: connection)
        await disconnect()
    }
}
