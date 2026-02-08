//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

import SwiftUI

@Observable
final class KHDevice: @MainActor KHDeviceProtocol {
    var state: KHState = KHState()
    var status: KHAccessStatus = .error("Not initialized")
    var parameterTree: SSCNode? = nil

    private let connection: SSCConnection

    struct KHDeviceID: Hashable, Codable {
        let name: String
        let serial: String
    }

    var id: KHDeviceID { .init(name: state.name, serial: state.serial) }

    required init(connection: SSCConnection) { self.connection = connection }

    private func connect() async {
        // Too quick to set status, it's too flickery
        // status = .busy("Connecting...")
        do {
            try await connection.open()
        } catch SSCConnection.ConnectionError.connectingTimedOut {
            status = .error("Connecting timed out")
        } catch {
            status = .error(String(describing: error))
        }
        // status = .ready
    }

    private func disconnect() async { await connection.close() }

    private func _fetchParameters(_ parameters: [KHParameters]) async {
        for p in parameters {
            do {
                state = try await p.fetch(into: state, connection: connection)
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
        status = .ready
    }

    private func _sendParameters(_ parameters: [KHParameters], newState: KHState) async {
        for p in parameters {
            do {
                try await p.send(
                    oldState: state,
                    newState: newState,
                    connection: connection
                )
            } catch {
                status = .error(String(describing: error))
                return
            }
            state = p.copy(from: newState, into: state)
        }
        status = .ready
    }

    func setup() async {
        status = .busy("Setting up...")
        await connect()
        // We need to fetch product and version to identify the schema type.
        await _fetchParameters(KHParameters.setupParameters)
        await populateParameters()
        await disconnect()
        // We do NOT update the state now because that messes up the ID
    }

    func fetch() async {
        status = .busy("Fetching...")
        await connect()
        await _fetchParameters(KHParameters.fetchParameters)
        await disconnect()
    }

    func send(_ newState: KHState) async {
        if newState == state {
            // don't even connect
            return
        }
        await connect()
        await _sendParameters(KHParameters.sendParameters, newState: newState)
        await disconnect()
    }

    func populateParameters() async {
        status = .busy("Loading parameters...")
        let rootNode = SSCNode(name: "root", deviceID: self.id, parent: nil)
        let schemaCache = SchemaCache()
        var cachedSchema: JSONDataCodable? = nil
        do {
            cachedSchema = try schemaCache.getSchema(for: self)
        } catch {
            print("Error loading cached schema: \(error)")
        }
        if let cachedSchema {
            rootNode.populate(jsonDataCodable: cachedSchema)
        } else {
            await connect()
            do {
                try await rootNode.populate(connection: connection, recursive: true)
            } catch {
                status = .error("Failed to load parameter tree: \(error)")
                return
            }
            await disconnect()
            do {
                try schemaCache.saveSchema(rootNode, for: self)
            } catch {
                print("Error saving schema: \(error)")
            }
        }
        parameterTree = rootNode
        status = .ready
    }
    
    private func _fetchNodes(_ nodes: [SSCNode]) async {
        for node in nodes {
            do {
                try await node.fetch(connection: connection)
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
        status = .ready
    }
    
    private func _sendNodes(_ nodes: [SSCNode]) async {
        for node in nodes {
            do {
                try await node.send(connection: connection)
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
        status = .ready
    }

    func fetchParameterTree() async {
        status = .busy("Fetching parameters...")
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }
        await connect()
        await _fetchNodes(rootNode.filter({$0.isLeaf()}))
        await disconnect()
    }

    func sendParameterTree() async {
        status = .busy("Sending parameters...")
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }
        await connect()
        await _sendNodes(rootNode.filter({$0.isLeaf()}))
        await disconnect()
    }

    func sendNode(path: [String]) async {
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }
        guard let node = rootNode.getAtPath(path) else {
            status = .error("Node not found")
            return
        }
        await connect()
        await _sendNodes([node])
        await disconnect()
    }

    func fetchNode(path: [String]) async {
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }
        guard let node = rootNode.getAtPath(path) else {
            status = .error("Node not found")
            return
        }
        await connect()
        await _fetchNodes([node])
        await disconnect()
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? { parameterTree?.getNodeByID(id) }
}
