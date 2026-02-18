//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

import SwiftUI

typealias KHAccess = KHDeviceGroup

@MainActor
protocol KHDevicesProtocol {
    var status: KHDeviceStatus { get }
    func setup() async -> KHState
    func fetch() async -> KHState
    func send(_: KHState) async
    func populateParameters() async
    func sendParameterTree() async
    func fetchParameterTree() async
    func getNodeByID(_: SSCNode.ID) -> SSCNode?
}

protocol KHSingleDeviceProtocol: KHDevicesProtocol, Identifiable {
    init(connection: SSCConnection)
    func sendNode(path: [String]) async
    func fetchNode(path: [String]) async
}

protocol KHDeviceGroupProtocol: KHDevicesProtocol {
    var devices: [KHDevice] { get }
    func getDeviceByID(_: KHDevice.ID) -> KHDevice?
    func scan(seconds: UInt32) async
}

enum KHDeviceStatus: Equatable {
    case ready
    case busy(String)
    case error(String)

    func isBusy() -> Bool {
        switch self {
        case .busy:
            return true
        default:
            return false
        }
    }

    static func aggregate(_ stati: [KHDeviceStatus]) -> KHDeviceStatus {
        guard !stati.isEmpty else {
            return .error("No devices")
        }
        return stati.reduce(.ready) { partial, next in
            if next == partial { return partial }
            switch (partial, next) {
            case (.ready, .busy(let msg)), (.busy(let msg), .ready):
                return .busy(msg)
            case (.ready, .error(let msg)), (.error(let msg), .ready):
                return .error(msg)
            case (.busy(let msg1), .busy(let msg2)):
                return .busy("\(msg1), \(msg2)")
            case (.error(let msg1), .error(let msg2)):
                return .error("\(msg1), \(msg2)")
            case (.error(let E), .busy(let B)), (.busy(let B), .error(let E)):
                return .busy("\(B), \(E)")
            default:
                return .error("Status aggregation fallback")
            }
        }
    }
}

@Observable
final class KHDevice: @MainActor KHSingleDeviceProtocol {
    private var state: KHState = KHState()
    var status: KHDeviceStatus = .error("Not initialized")
    var parameterTree: SSCNode? = nil

    private let connection: SSCConnection

    struct KHDeviceID: Hashable, Codable {
        let name: String
        let serial: String
    }

    var id: KHDeviceID { .init(name: state.name, serial: state.serial) }

    required init(connection: SSCConnection) { self.connection = connection }

    private func _fetchParameters(_ parameters: [KHParameters]) async {
        for p in parameters {
            do {
                state = try await p.fetch(
                    into: state,
                    connection: connection,
                    parameterTree: parameterTree
                )
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
        status = .ready
    }

    private func _sendParameters(_ parameters: [KHParameters], newState: KHState) async
    {
        for p in parameters {
            do {
                try await p.send(
                    oldState: state,
                    newState: newState,
                    connection: connection,
                    parameterTree: parameterTree
                )
            } catch {
                status = .error(String(describing: error))
                return
            }
            /// We only want to copy these parameters and not update the whole state because we can get a single state with Name etc. from KHDeviceGroup and don't want to overwrite names of devices.
            state = p.copy(from: newState, into: state)
        }
        status = .ready
    }

    func setup() async -> KHState {
        status = .busy("Setting up")
        // We need to fetch product and version to identify the schema type.
        await _fetchParameters(KHParameters.setupParameters)
        await populateParameters()
        // We do NOT update the state now because that messes up the ID
        return state
    }

    func fetch() async -> KHState {
        status = .busy("Fetching")
        await _fetchParameters(KHParameters.fetchParameters)
        return state
    }

    func send(_ newState: KHState) async {
        await _sendParameters(KHParameters.sendParameters, newState: newState)
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
            rootNode.populate(from: cachedSchema)
        } else {
            do {
                try await rootNode.populate(connection: connection, recursive: true)
            } catch {
                status = .error("Failed to load parameter tree: \(error)")
                return
            }
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
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }

        status = .busy("Fetching parameters...")
        await _fetchNodes(rootNode.filter({ $0.isLeaf() }))
        /// I'm not sure if this actually makes sense. We only store the schema per device type, not per device.
        /*
        let sc = SchemaCache()
        do {
            try sc.saveSchema(rootNode, for: self)
        } catch {
            print("Error saving schema: \(error)")
        }
         */
    }

    func sendParameterTree() async {
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return
        }

        status = .busy("Sending parameters...")
        await _sendNodes(rootNode.filter({ $0.isLeaf() }))
    }

    private func _getNodeAtPath(_ path: [String]) -> SSCNode? {
        guard let rootNode = parameterTree else {
            status = .error("Parameters not loaded")
            return nil
        }
        guard let node = rootNode.getAtPath(path) else {
            status = .error("Node not found")
            return nil
        }
        return node
    }

    func sendNode(path: [String]) async {
        guard let node = _getNodeAtPath(path) else { return }
        await _sendNodes([node])
    }

    func fetchNode(path: [String]) async {
        guard let node = _getNodeAtPath(path) else { return }
        await _fetchNodes([node])
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? { parameterTree?.getNodeByID(id) }
}

@Observable
final class KHDeviceGroup: KHDeviceGroupProtocol {
    private var statusOverride: KHDeviceStatus? = nil
    var status: KHDeviceStatus {
        statusOverride ?? KHDeviceStatus.aggregate(devices.map(\.status))
    }
    var devices: [KHDevice] = []

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        statusOverride = .busy("Scanning...")
        let connectionCache = ConnectionCache()
        do {
            try await connectionCache.clearConnections()
        } catch {
            print(error)
        }
        let connections = await SSCConnection.scan(seconds: seconds)
        if connections.isEmpty {
            statusOverride = .error("No devices found")
            return
        }
        do {
            try await connectionCache.saveConnections(connections)
        } catch {
            print(error)
        }
        devices = connections.map { KHDevice(connection: $0) }
        statusOverride = nil
    }

    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice? {
        return devices.first(where: { $0.id == id })
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? {
        // devices.compactMap { $0.getNodeByID(id) }.first
        guard let owner = getDeviceByID(id.deviceID) else { return nil }
        return owner.getNodeByID(id)
    }

    func setup() async -> KHState{
        if !devices.isEmpty {
            return await setupDevices()
        }
        let connectionCache = ConnectionCache()
        do {
            let connections = try connectionCache.getConnections()
            if connections.isEmpty {
                await scan()
            } else {
                devices = connections.map { KHDevice(connection: $0) }
            }
        } catch {
            print("error loading connection cache: \(error)")
            await scan()
        }
        return await setupDevices()
    }

    private func setupDevices() async -> KHState {
        // We don't want to do this in parallel (naively) because of file system cache
        for d in devices {
            _ = await d.setup()
        }
        // not sure
        // await fetchParameters()
        return await fetch()
    }

    func populateParameters() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.populateParameters() }
            }
            await group.waitForAll()
        }
    }

    func fetchParameterTree() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetchParameterTree() }
            }
            await group.waitForAll()
        }
    }

    func sendParameterTree() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.sendParameterTree() }
            }
            await group.waitForAll()
        }
    }

    func fetch() async -> KHState {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetch() }
            }
            var results: [KHState] = []
            for await state in group {
                results.append(state)
            }
            // await group.waitForAll()
            return results.first ?? KHState()
        }
    }

    func send(_ state: KHState) async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.send(state) }
            }
            await group.waitForAll()
        }
    }
}
