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
    var state: KHState { get }
    var status: KHDeviceStatus { get }
    func setup() async
    func fetch() async
    func sendParameterTree() async
    func fetchParameterTree() async
    func getNodeByID(_: SSCNode.ID) -> SSCNode?
}

protocol KHSingleDeviceProtocol: KHDevicesProtocol, Identifiable {
    func send(_: KHState) async

    // Truly specific
    init(connection: SSCConnection)
    func sendNode(path: [String]) async
    func fetchNode(path: [String]) async
}

protocol KHDeviceGroupProtocol: KHDevicesProtocol {
    func send() async

    // Truly specific
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

struct KHDeviceID: Hashable, Codable {
    let name: String
    let serial: String
}

struct DeviceModelID: Codable, Hashable {
    let product: String
    let version: String

    init(_ state: KHState) {
        product = state.product
        version = state.version
    }
}

@Observable
final class KHDevice: @MainActor KHSingleDeviceProtocol {
    var state: KHState
    var status: KHDeviceStatus = .error("Not initialized")
    var parameterTree: SSCNode? = nil

    private let connection: SSCConnection

    var id: KHDeviceID { .init(name: state.name, serial: state.serial) }

    required init(connection: SSCConnection) {
        state = KHState()
        self.connection = connection
    }
    
    init(deviceID: KHDevice.ID, modelID: DeviceModelID, connection: SSCConnection) {
        self.connection = connection
        state = KHState()
        state.name = deviceID.name
        state.serial = deviceID.serial
        state.product = modelID.product
        state.version = modelID.version
    }
    
    private func updateCachedState() {
        do {
            let stateCache = try StateCache()
            try stateCache.saveState(for: self)
        } catch {
            print("Error updating cache:", error)
        }
    }
    
    private func _fetchParameter(_ parameter: KHParameters) async {
        do {
            state = try await parameter.fetch(
                into: state,
                connection: connection,
                parameterTree: parameterTree
            )
        } catch {
            status = .error(String(describing: error))
        }
    }
    
    private func _sendParameter(_ parameter: KHParameters, newState: KHState) async {
        do {
            try await parameter.send(
                oldState: state,
                newState: newState,
                connection: connection,
                parameterTree: parameterTree
            )
            /// We only want to copy these parameters and not update the whole state because we can get a single state with Name etc. from KHDeviceGroup and don't want to overwrite names of devices.
            state = parameter.copy(from: newState, into: state)
        } catch SSCConnection.DeviceError.notAcceptable {
            status = .error("Rejected by device")
        } catch {
            status = .error(String(describing: error))
        }
    }
    
    private func _fetchParameterGroup(_ parameterGroup: KHParameterGroup) async {
        for p in parameterGroup.parameters() {
            await _fetchParameter(p)
            if case .error = status { return }
        }
        status = .ready
    }
    
    private func _sendParameterGroup(_ parameterGroup: KHParameterGroup, newState: KHState) async
    {
        for p in parameterGroup.parameters() {
            await _sendParameter(p, newState: newState)
            if case .error = status { return }
        }
        status = .ready
    }

    func fetch() async {
        status = .busy("Fetching...")
        await _fetchParameterGroup(.fetch)
        updateCachedState()
    }

    func send(_ newState: KHState) async {
        await _sendParameterGroup(.send, newState: newState)
    }

    private func populateParameters() async throws {
        status = .busy("Loading parameters...")
        let rootNode = SSCNode(name: "root", deviceID: self.id, parent: nil)

        // Load parameter tree structure without values from cache or device
        let schemaCache = try SchemaCache()
        if let cachedSchema = try schemaCache.getSchema(for: self) {
            rootNode.populate(from: cachedSchema)
        } else {
            try await rootNode.populate(connection: connection, recursive: true)
            let schemaCache = try SchemaCache()
            try schemaCache.saveSchema(rootNode, for: self)
        }
        parameterTree = rootNode
    }

    private func loadParameterValues() async throws  {
        guard let rootNode = parameterTree else {
            status = .error("Initial loading failed: Parameters not populated")
            return
        }
        let stateCache = try StateCache()
        if let cachedState = try stateCache.getState(for: self) {
            try rootNode.load(from: cachedState.1)
            state = cachedState.0
        } else {
            await fetchParameterTree()
        }
        status = .ready
    }
    
    func setup() async {
        status = .busy("Setting up")
        // We need to fetch product and version to identify the schema type.
        await _fetchParameterGroup(.setup)
        do {
            try await populateParameters()
        } catch {
            status = .error("Error populating parameters: \(error)")
            return
        }
        do {
            try await loadParameterValues()
        } catch {
            status = .error("Error loading parameters: \(error)")
        }
        // We do NOT update the state now because that messes up the ID
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
        updateCachedState()
        status = .ready
    }

    private func _sendNodes(_ nodes: [SSCNode]) async {
        for node in nodes {
            do {
                try await node.send(connection: connection)
            } catch SSCConnection.DeviceError.notAcceptable, SSCConnection.DeviceError
                .methodNotAllowed
            {
                continue
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
    var state = KHState()
    private var statusOverride: KHDeviceStatus? = nil
    var status: KHDeviceStatus {
        statusOverride ?? KHDeviceStatus.aggregate(devices.map(\.status))
    }
    var devices: [KHDevice] = []

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        statusOverride = .busy("Scanning...")
        do {
            let connectionCache = try ConnectionCache()
            try connectionCache.clear()
        } catch {
            print("Error clearing connection cache:", error)
        }
        let connections = await SSCConnection.scan(seconds: seconds)
        if connections.isEmpty {
            statusOverride = .error("No devices found")
            return
        }
        do {
            let connectionCache = try ConnectionCache()
            try await connectionCache.saveConnections(connections)
        } catch {
            print("Error saving connection cache:", error)
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

    func setup() async {
        if !devices.isEmpty {
            await setupDevices()
            return
        }
        var connections: [SSCConnection] = []
        do {
            let connectionCache = try ConnectionCache()
            connections = try connectionCache.getConnections()
        } catch {
            print("error loading connection cache: \(error)")
        }
        if connections.isEmpty {
            await scan()
        } else {
            devices = connections.map { KHDevice(connection: $0) }
        }
        await setupDevices()
    }

    private func setupDevices() async {
        // We don't want to do this in parallel (naively) because of file system cache
        for d in devices {
            await d.setup()
        }
        // not sure
        // await fetchParameters()
        // await fetch()
        guard !devices.isEmpty else { return }
        state = devices.first!.state
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

    func fetch() async {
        guard !devices.isEmpty else { return }

        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetch() }
            }
            await group.waitForAll()
            state = devices.first!.state
        }
    }

    func send() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.send(self.state) }
            }
            await group.waitForAll()
        }
    }
}
