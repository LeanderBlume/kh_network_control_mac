//
//  KHJSON.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct KHState: Codable, Equatable {
    var name = "Unknown name"
    var serial = "Unknown serial"
    var product = "Unknown model"
    var version = "Unknown version"
    var volume = 54.0
    var eqs = [Eq(numBands: 10), Eq(numBands: 20)]
    var muted = false
    var logoBrightness = 100.0
    var standbyEnabled = false
    var standbyTimeout = 90.0

    init() {}

    init?(jsonData: JSONData, deviceModel: DeviceModel) {
        for p in KHParameters.allCases {
            guard
                let newState = p.copy(
                    from: jsonData,
                    into: self,
                    deviceModel: deviceModel
                )
            else { return nil }
            self = newState
        }
    }

    init?(jsonDataCodable: JSONDataCodable, deviceModel: DeviceModel) {
        self.init(
            jsonData: JSONData(jsonDataCodable: jsonDataCodable),
            deviceModel: deviceModel
        )
    }

    @MainActor
    init?(nodeTree: SSCNode, deviceModel: DeviceModel) {
        guard let jd = JSONData(rootNode: nodeTree) else { return nil }
        self.init(jsonData: jd, deviceModel: deviceModel)
    }
}

private protocol KHStatePathProtocol: Equatable {
    associatedtype T: Equatable, Codable, Sendable

    var keyPath: WritableKeyPath<KHState, T> { get }

    func copy(from: KHState, into: KHState) -> KHState
    func copy(from: JSONData, into: KHState, devicePath: [String]) -> KHState?
    @MainActor func copy(from: KHState, into: SSCNode, devicePath: [String])

    func fetch(
        into: KHState,
        connection: SSCConnection,
        devicePath: [String],
        parameterTree: SSCNode?
    ) async throws -> KHState

    func send(
        oldState: KHState,
        newState: KHState,
        connection: SSCConnection,
        devicePath: [String],
        parameterTree: SSCNode?
    ) async throws
}

private struct KHStatePath<T>: KHStatePathProtocol
where T: Equatable, T: Codable, T: Sendable {
    let keyPath: WritableKeyPath<KHState, T>

    private func get(from state: KHState) -> T {
        state[keyPath: keyPath]
    }

    private func get(from jsonData: JSONData) -> T? {
        switch jsonData {
        case .array:
            jsonData.asArrayAny() as? T
        default:
            jsonData.asAny() as? T
        }
    }

    private func set(_ value: T, into state: KHState) -> KHState {
        var newState = state
        newState[keyPath: keyPath] = value
        return newState
    }

    private func set(_ jsonData: JSONData, into state: KHState) -> KHState? {
        guard let value = get(from: jsonData) else { return nil }
        return set(value, into: state)
    }

    func copy(from sourceState: KHState, into targetState: KHState) -> KHState {
        set(get(from: sourceState), into: targetState)
    }

    func copy(
        from jsonData: JSONData,
        into targetState: KHState,
        devicePath: [String]
    ) -> KHState? {
        guard let value = jsonData.getAtPath(devicePath) else { return nil }
        return set(value, into: targetState)
    }

    @MainActor
    func copy(from state: KHState, into nodeTree: SSCNode, devicePath: [String]) {
        guard let leaf = nodeTree.getAtPath(devicePath) else { return }
        guard case .value(let val) = leaf.value else { return }
        switch val {
        case .bool:
            guard let v = get(from: state) as? Bool else { return }
            leaf.value = .value(JSONData(singleValue: v))
        case .number:
            guard let v = get(from: state) as? Double else { return }
            leaf.value = .value(JSONData(singleValue: v))
        case .string:
            guard let v = get(from: state) as? String else { return }
            leaf.value = .value(JSONData(singleValue: v))
        case .array(let a):
            switch a.first {
            case .bool:
                guard let v = get(from: state) as? [Bool] else { return }
                leaf.value = .value(JSONData(singleValue: v))
            case .number:
                guard let v = get(from: state) as? [Double] else { return }
                leaf.value = .value(JSONData(singleValue: v))
            case .string:
                guard let v = get(from: state) as? [String] else { return }
                leaf.value = .value(JSONData(singleValue: v))
            default:
                return
            }
        default:
            return
        }
    }

    @MainActor
    func fetch(
        into state: KHState,
        connection: SSCConnection,
        devicePath: [String],
        parameterTree: SSCNode? = nil
    ) async throws -> KHState {
        let newValue: T = try await connection.fetchSSCValue(path: devicePath)
        var newState = state
        newState[keyPath: keyPath] = newValue
        if let parameterTree {
            copy(from: newState, into: parameterTree, devicePath: devicePath)
        }
        return newState
    }

    @MainActor
    func send(
        oldState: KHState,
        newState: KHState,
        connection: SSCConnection,
        devicePath: [String],
        parameterTree: SSCNode? = nil
    )
        async throws
    {
        if oldState[keyPath: keyPath] == newState[keyPath: keyPath] { return }
        try await connection.sendSSCValue(
            path: devicePath,
            value: newState[keyPath: keyPath]
        )
        if let parameterTree {
            copy(from: newState, into: parameterTree, devicePath: devicePath)
        }
    }
}

enum KHParameters2: Identifiable, CaseIterable {
    case name(String)
    case serial(String)
    case product(String)
    case version(String)
    case volume(Double)
    case muted(Bool)
    case logoBrightness(Double)
    case standbyEnabled(Bool)
    case standbyTimeout(Double)

    case eq0enabled([Bool])
    case eq0type([String])
    case eq0frequency([Double])
    case eq0boost([Double])
    case eq0q([Double])
    case eq0gain([Double])

    case eq1enabled([Bool])
    case eq1type([String])
    case eq1frequency([Double])
    case eq1boost([Double])
    case eq1q([Double])
    case eq1gain([Double])

    var id: String { getName() }

    static let allCases: [KHParameters2] = [
        .name(""),
        .serial(""),
        .product(""),
        .version(""),
        .volume(0.0),
        .muted(false),
        .logoBrightness(0.0),
        .standbyEnabled(false),
        .standbyTimeout(0.0),

        .eq0enabled([]),
        .eq0type([]),
        .eq0frequency([]),
        .eq0boost([]),
        .eq0q([]),
        .eq0gain([]),

        .eq1enabled([]),
        .eq1type([]),
        .eq1frequency([]),
        .eq1boost([]),
        .eq1q([]),
        .eq1gain([]),
    ]

    private func getName() -> String {
        switch self {
        case .name: "Name"
        case .serial: "Serial"
        case .product: "Product"
        case .version: "Version"
        case .volume: "Volume"
        case .muted: "Mute"
        case .logoBrightness: "Logo brightness"
        case .standbyEnabled: "Enable auto-standby"
        case .standbyTimeout: "Auto-standby timeout"

        case .eq0boost: "EQ 1 Boost"
        case .eq0enabled: "EQ 1 Enabled"
        case .eq0frequency: "EQ 1 Frequency"
        case .eq0gain: "EQ 1 Gain"
        case .eq0q: "EQ 1 Q"
        case .eq0type: "EQ 1 Type"

        case .eq1boost: "EQ 2 Boost"
        case .eq1enabled: "EQ 2 Enabled"
        case .eq1frequency: "EQ 2 Frequency"
        case .eq1gain: "EQ 2 Gain"
        case .eq1q: "EQ 2 Q"
        case .eq1type: "EQ 2 Type"
        }
    }

    func getDevicePathFallback() -> [String] {
        switch self {
        case .name:
            ["device", "name"]
        case .serial:
            ["device", "identity", "serial"]
        case .product:
            ["device", "identity", "product"]
        case .version:
            ["device", "identity", "version"]
        case .volume:
            ["audio", "out", "level"]
        case .muted:
            ["audio", "out", "mute"]
        case .logoBrightness:
            ["ui", "logo", "brightness"]
        case .standbyEnabled:
            ["device", "standby", "enabled"]
        case .standbyTimeout:
            ["device", "standby", "auto_standby_time"]

        case .eq0boost:
            ["audio", "out", "eq2", "boost"]
        case .eq0enabled:
            ["audio", "out", "eq2", "enabled"]
        case .eq0frequency:
            ["audio", "out", "eq2", "frequency"]
        case .eq0gain:
            ["audio", "out", "eq2", "gain"]
        case .eq0q:
            ["audio", "out", "eq2", "q"]
        case .eq0type:
            ["audio", "out", "eq2", "type"]

        case .eq1boost:
            ["audio", "out", "eq3", "boost"]
        case .eq1enabled:
            ["audio", "out", "eq3", "enabled"]
        case .eq1frequency:
            ["audio", "out", "eq3", "frequency"]
        case .eq1gain:
            ["audio", "out", "eq3", "gain"]
        case .eq1q:
            ["audio", "out", "eq3", "q"]
        case .eq1type:
            ["audio", "out", "eq3", "type"]
        }
    }
}

enum KHParameters: String, CaseIterable, Identifiable {
    case name = "Name"
    case serial = "Serial"
    case product = "Product"
    case version = "Version"
    case volume = "Volume"
    case muted = "Mute"
    case logoBrightness = "Logo brightness"
    case standbyEnabled = "Enable auto-standby"
    case standbyTimeout = "Auto-standby timeout"

    case eq0boost = "EQ 1 Boost"
    case eq0enabled = "EQ 1 Enabled"
    case eq0frequency = "EQ 1 Frequency"
    case eq0gain = "EQ 1 Gain"
    case eq0q = "EQ 1 Q"
    case eq0type = "EQ 1 Type"

    case eq1boost = "EQ 2 Boost"
    case eq1enabled = "EQ 2 Enabled"
    case eq1frequency = "EQ 2 Frequency"
    case eq1gain = "EQ 2 Gain"
    case eq1q = "EQ 2 Q"
    case eq1type = "EQ 2 Type"

    var id: String { self.rawValue }

    func getDevicePathFallback() -> [String] {
        switch self {
        case .name:
            ["device", "name"]
        case .serial:
            ["device", "identity", "serial"]
        case .product:
            ["device", "identity", "product"]
        case .version:
            ["device", "identity", "version"]
        case .volume:
            ["audio", "out", "level"]
        case .muted:
            ["audio", "out", "mute"]
        case .logoBrightness:
            ["ui", "logo", "brightness"]
        case .standbyEnabled:
            ["device", "standby", "enabled"]
        case .standbyTimeout:
            ["device", "standby", "auto_standby_time"]

        case .eq0boost:
            ["audio", "out", "eq2", "boost"]
        case .eq0enabled:
            ["audio", "out", "eq2", "enabled"]
        case .eq0frequency:
            ["audio", "out", "eq2", "frequency"]
        case .eq0gain:
            ["audio", "out", "eq2", "gain"]
        case .eq0q:
            ["audio", "out", "eq2", "q"]
        case .eq0type:
            ["audio", "out", "eq2", "type"]

        case .eq1boost:
            ["audio", "out", "eq3", "boost"]
        case .eq1enabled:
            ["audio", "out", "eq3", "enabled"]
        case .eq1frequency:
            ["audio", "out", "eq3", "frequency"]
        case .eq1gain:
            ["audio", "out", "eq3", "gain"]
        case .eq1q:
            ["audio", "out", "eq3", "q"]
        case .eq1type:
            ["audio", "out", "eq3", "type"]
        }
    }

    private func getPathObject() -> any KHStatePathProtocol {
        switch self {
        case .name:
            KHStatePath(keyPath: \.name)
        case .serial:
            KHStatePath(keyPath: \.serial)
        case .product:
            KHStatePath(keyPath: \.product)
        case .version:
            KHStatePath(keyPath: \.version)
        case .volume:
            KHStatePath(keyPath: \.volume)
        case .muted:
            KHStatePath(keyPath: \.muted)
        case .logoBrightness:
            KHStatePath(keyPath: \.logoBrightness)
        case .standbyEnabled:
            KHStatePath(keyPath: \.standbyEnabled)
        case .standbyTimeout:
            KHStatePath(keyPath: \.standbyTimeout)

        case .eq0boost:
            KHStatePath(keyPath: \.eqs[0].boost)
        case .eq0enabled:
            KHStatePath(keyPath: \.eqs[0].enabled)
        case .eq0frequency:
            KHStatePath(keyPath: \.eqs[0].frequency)
        case .eq0gain:
            KHStatePath(keyPath: \.eqs[0].gain)
        case .eq0q:
            KHStatePath(keyPath: \.eqs[0].q)
        case .eq0type:
            KHStatePath(keyPath: \.eqs[0].type)

        case .eq1boost:
            KHStatePath(keyPath: \.eqs[1].boost)
        case .eq1enabled:
            KHStatePath(keyPath: \.eqs[1].enabled)
        case .eq1frequency:
            KHStatePath(keyPath: \.eqs[1].frequency)
        case .eq1gain:
            KHStatePath(keyPath: \.eqs[1].gain)
        case .eq1q:
            KHStatePath(keyPath: \.eqs[1].q)
        case .eq1type:
            KHStatePath(keyPath: \.eqs[1].type)
        }
    }

    func copy(from sourceState: KHState, into targetState: KHState) -> KHState {
        getPathObject().copy(from: sourceState, into: targetState)
    }

    func copy(
        from jsonData: JSONData,
        into targetState: KHState,
        deviceModel: DeviceModel
    ) -> KHState? {
        getPathObject().copy(
            from: jsonData,
            into: targetState,
            devicePath: deviceModel.getDevicePath(for: self)
        )
    }

    @MainActor
    func copy(from state: KHState, into nodeTree: SSCNode, deviceModel: DeviceModel) {
        getPathObject().copy(
            from: state,
            into: nodeTree,
            devicePath: deviceModel.getDevicePath(for: self)
        )
    }

    func fetch(
        into state: KHState,
        connection: SSCConnection,
        deviceModel: DeviceModel,
        parameterTree: SSCNode? = nil
    ) async throws -> KHState {
        try await getPathObject().fetch(
            into: state,
            connection: connection,
            devicePath: deviceModel.getDevicePath(for: self),
            parameterTree: parameterTree
        )
    }

    func send(
        oldState: KHState,
        newState: KHState,
        connection: SSCConnection,
        deviceModel: DeviceModel,
        parameterTree: SSCNode? = nil
    ) async throws {
        try await getPathObject().send(
            oldState: oldState,
            newState: newState,
            connection: connection,
            devicePath: deviceModel.getDevicePath(for: self),
            parameterTree: parameterTree
        )
    }
}

enum KHParameterGroup {
    case setup
    case fetch
    case send

    func parameters() -> [KHParameters] {
        switch self {
        case .fetch:
            return [
                .volume,
                .muted,
                .logoBrightness,
                .eq0boost,
                .eq0enabled,
                .eq0frequency,
                .eq0gain,
                .eq0q,
                .eq0type,
                .eq1boost,
                .eq1enabled,
                .eq1frequency,
                .eq1gain,
                .eq1q,
                .eq1type,
                .name,
                .standbyEnabled,
                .standbyTimeout,
            ]
        case .send:
            return [
                .volume,
                .muted,
                .logoBrightness,
                .eq0boost,
                .eq0enabled,
                .eq0frequency,
                .eq0gain,
                .eq0q,
                .eq0type,
                .eq1boost,
                .eq1enabled,
                .eq1frequency,
                .eq1gain,
                .eq1q,
                .eq1type,
                .standbyEnabled,
                .standbyTimeout,
            ]
        case .setup:
            return [
                .name,
                .serial,
                .product,
                .version,
            ]
        }
    }
}
