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

    func setup() async
    func fetch() async -> KHState
    func send(_: KHState) async

    func sendParameterTree() async
    func fetchParameterTree() async

    func getNodeByID(_: SSCNode.ID) -> SSCNode?
}

protocol KHSingleDeviceProtocol: KHDevicesProtocol, Identifiable {
    var product: String { get }
    var serial: String { get }
    var version: String { get }
    var state: KHState { get set }

    init(connection: SSCConnection, product: String, serial: String, version: String)
    init(_ connection: SSCConnection) async throws

    func getModel() -> DeviceModel
    func sendNode(path: [String]) async
    func fetchNode(path: [String]) async
}

protocol KHDeviceGroupProtocol: KHDevicesProtocol {
    var devices: [KHDevice] { get }

    func fetchAll() async -> [KHState]
    func sendIdentified(_ state: KHState) async
    func sendIndividual(_ states: [KHState]) async

    func getDeviceByID(_: KHDevice.ID) -> KHDevice?
    func getDeviceByModel(_: DeviceModel) -> KHDevice?
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
    let product: String
    let serial: String
    let version: String
    var state: KHState
    var status: KHDeviceStatus = .error("Not initialized")
    var parameterTree: SSCNode? = nil

    private let connection: SSCConnection

    let id: String

    required init(
        connection: SSCConnection,
        product: String,
        serial: String,
        version: String
    ) {
        self.connection = connection
        self.product = product
        self.serial = serial
        self.version = version
        id = "\(product)_\(serial)"
        state = .init(deviceID: id)
    }

    convenience init(_ connection: SSCConnection) async throws {
        let product: String = try await connection.fetchSSCValue(path: [
            "device", "identity", "product",
        ])
        let serial: String = try await connection.fetchSSCValue(path: [
            "device", "identity", "serial",
        ])
        let version: String = try await connection.fetchSSCValue(path: [
            "device", "identity", "version",
        ])
        self.init(
            connection: connection,
            product: product,
            serial: serial,
            version: version
        )
    }

    private func updateCachedState() {
        do {
            let stateCache = try StateCache()
            try stateCache.saveState(for: self)
        } catch {
            print("Error updating cache:", error)
        }
    }

    private func updateStateFromParameterTree() {
        guard let rootNode = parameterTree else {
            print("Parameters not populated, cannot update state")
            return
        }
        guard
            let newState = KHState(
                nodeTree: rootNode,
                deviceModel: getModel(),
                deviceID: id
            )
        else {
            print("Failed to create KHState from parameter tree")
            return
        }
        state = newState
    }

    func getModel() -> DeviceModel { DeviceModel(self) }

    private func _fetchParameter(_ parameter: SSCParameter) async throws {
        do {
            state = try await parameter.fetch(
                into: state,
                connection: connection,
                deviceModel: getModel(),
                parameterTree: parameterTree
            )
        } catch SSCConnection.ConnectionError.connectingTimedOut {
            status = .error("Device not reachable")
            throw SSCConnection.ConnectionError.connectingTimedOut
        } catch {
            status = .error(String(describing: error))
            throw error
        }
    }

    private func _sendParameter(_ parameter: SSCParameter, newState: KHState)
        async throws
    {
        do {
            try await parameter.send(
                oldState: state,
                newState: newState,
                connection: connection,
                deviceModel: getModel(),
                parameterTree: parameterTree
            )
            /// We only want to copy these parameters and not update the whole state because we can get a single state with Name etc. from KHDeviceGroup and don't want to overwrite names of devices.
            state = parameter.copy(from: newState, into: state)
        } catch SSCConnection.DeviceError.notAcceptable {
            status = .error("Rejected by device")
            throw SSCConnection.DeviceError.notAcceptable
        } catch {
            status = .error(String(describing: error))
            throw error
        }
    }

    private func _fetchParameterGroup(_ parameterGroup: KHParameterGroup) async throws {
        for p in parameterGroup.parameters(getModel()) {
            try await _fetchParameter(p)
        }
        status = .ready
    }

    private func _sendParameterGroup(
        _ parameterGroup: KHParameterGroup,
        newState: KHState
    ) async throws {
        for p in parameterGroup.parameters(getModel()) {
            try await _sendParameter(p, newState: newState)
        }
        status = .ready
    }

    func fetch() async -> KHState {
        status = .busy("Fetching...")
        do {
            try await _fetchParameterGroup(.fetch)
        } catch {
            status = .error("Error fetching: \(error)")
            return state
        }
        updateCachedState()
        return state
    }

    func send(_ newState: KHState) async {
        do {
            try await _sendParameterGroup(.send, newState: newState)
        } catch {
            status = .error("Error sending: \(error)")
        }
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

    private func loadParameterValues() async throws {
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
        updateStateFromParameterTree()
        updateCachedState()
        status = .ready
    }

    private func _sendNodes(_ nodes: [SSCNode]) async {
        for node in nodes {
            do {
                try await node.send(connection: connection)
            } catch
                SSCConnection.DeviceError.notAcceptable,
                SSCConnection.DeviceError.methodNotAllowed,
                SSCConnection.DeviceError.partialSuccess,
                SSCConnection.DeviceError.parameterAddressNotFound
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
    private var statusOverride: KHDeviceStatus? = nil
    var status: KHDeviceStatus {
        statusOverride ?? KHDeviceStatus.aggregate(devices.map(\.status))
    }
    var devices: [KHDevice] = []

    static private func connectionsToDevices(_ connections: [SSCConnection]) async
        -> [KHDevice]
    {
        var devices = [KHDevice]()
        for connection in connections {
            do {
                devices.append(try await KHDevice(connection))
            } catch {
                print("Error initializing device:", error)
                continue
            }
        }
        return devices
    }

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
        devices = await Self.connectionsToDevices(connections)
        statusOverride = nil
    }

    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice? {
        devices.first(where: { $0.id == id })
    }

    func getDeviceByModel(_ deviceModel: DeviceModel) -> KHDevice? {
        devices.first(where: { $0.getModel() == deviceModel })
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? {
        // devices.compactMap { $0.getNodeByID(id) }.first
        guard let owner = getDeviceByID(id.deviceID) else { return nil }
        return owner.getNodeByID(id)
    }

    private func populateDevices() async {
        guard devices.isEmpty else { return }
        var connections: [SSCConnection] = []
        do {
            connections = try ConnectionCache().getConnections()
        } catch {
            print("error loading connection cache: \(error)")
        }
        if connections.isEmpty {
            await scan()
        } else {
            devices = await Self.connectionsToDevices(connections)
        }
    }

    func setup() async {
        await populateDevices()
        for d in devices {
            await d.setup()
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

    func fetchAll() async -> [KHState] {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetch() }
            }
            var results: [KHState] = []
            for await state in group {
                results.append(state)
            }
            return results
        }
    }

    func fetch() async -> KHState { await fetchAll().first ?? KHState(deviceID: nil) }

    func sendIdentified(_ state: KHState) async {
        guard let deviceID = state.deviceID else {
            print("Could not match state without deviceID to a device, skipping")
            return
        }
        guard let device = getDeviceByID(deviceID) else {
            print("Could not find device with id \(deviceID), skipping")
            return
        }
        await device.send(state)
    }

    func sendIndividual(_ states: [KHState]) async {
        guard states.count == devices.count else {
            statusOverride = .error(
                "Can't send \(states.count) states to \(devices.count) devices."
            )
            return
        }
        await withTaskGroup { group in
            for state in states {
                group.addTask { await self.sendIdentified(state) }
            }
            await group.waitForAll()
        }
    }

    func send(_ state: KHState) async {
        await withTaskGroup { group in
            for device in devices {
                group.addTask { await device.send(state) }
            }
            await group.waitForAll()
        }
    }
}
