//
//  KHJSON.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct KHState: Codable, Equatable {
    var name = "Unknown name"
    var volume = 54.0
    var muted = false
    var eqs = [Eq(numBands: 10), Eq(numBands: 20)]
    var logoBrightness = 100.0
    var standbyEnabled = false
    var standbyTimeout = 90.0
    var delay = 0.0
    var identify = false

    let deviceID: KHDevice.ID?

    init(deviceID: KHDevice.ID?) {
        self.deviceID = deviceID
    }

    init?(jsonData: JSONData, deviceModel: DeviceModel, deviceID: KHDevice.ID?) {
        var futureSelf: KHState = .init(deviceID: deviceID)
        for p in deviceModel.allParameters() {
            guard
                let updated = p.copy(
                    from: jsonData,
                    into: futureSelf,
                    deviceModel: deviceModel
                )
            else { return nil }
            futureSelf = updated
        }
        self = futureSelf
    }

    @MainActor
    init?(
        nodeTree: SSCNode,
        deviceModel: DeviceModel,
        deviceID: KHDevice.ID?
    ) {
        guard let jd = JSONData(rootNode: nodeTree) else { return nil }
        self.init(
            jsonData: jd,
            deviceModel: deviceModel,
            deviceID: deviceID
        )
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

    func allEqual(_ states: [KHState]) -> Bool
}

private struct KHStatePath<T>: KHStatePathProtocol
where T: Equatable, T: Codable, T: Sendable {
    let keyPath: WritableKeyPath<KHState, T>

    init(_ keyPath: WritableKeyPath<KHState, T>) {
        self.keyPath = keyPath
    }

    private func get(from state: KHState) -> T {
        state[keyPath: keyPath]
    }

    private func get(from jsonData: JSONData) -> T? {
        jsonData.asType()
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

    func allEqual(_ states: [KHState]) -> Bool {
        let vals = states.map { get(from: $0) }
        guard let first = vals.first else { return true }
        return vals.allSatisfy { $0 == first }
    }
}

enum EQParameter: CaseIterable, Equatable {
    case boost, enabled, frequency, gain, q, type

    func description() -> String { finalPathComponent().capitalized }

    func finalPathComponent() -> String {
        switch self {
        case .boost: "boost"
        case .enabled: "enabled"
        case .frequency: "frequency"
        case .gain: "gain"
        case .q: "q"
        case .type: "type"
        }
    }
}

enum SSCParameter: Identifiable, Equatable, Hashable {
    case name, volume, muted, logoBrightness, standbyEnabled, standbyTimeout, delay,
        identify
    case eq(_ index: Int, _ name: String, _ eqParameter: EQParameter)

    var id: String { self.description() }

    static var allDefaultParameters: [SSCParameter] {
        var result: [SSCParameter] = [
            .name,
            .volume,
            .muted,
            .logoBrightness,
            .standbyEnabled,
            .standbyTimeout,
            .delay,
            .identify,
        ]
        for (i, n) in [(0, "eq2"), (1, "eq3")] {
            for p in EQParameter.allCases {
                result.append(.eq(i, n, p))
            }
        }
        return result
    }

    func description() -> String {
        return switch self {
        case .name: "Name"
        case .volume: "Volume"
        case .muted: "Mute"
        case .logoBrightness: "Logo brightness"
        case .standbyEnabled: "Enable auto-standby"
        case .standbyTimeout: "Auto-standby timeout"
        case .delay: "Delay"
        case .identify: "Identify (flash LED)"
        case .eq(let i, _, let p): "EQ \(i) \(p.description())"
        }
    }

    func getDevicePathFallback() -> [String] {
        switch self {
        case .name:
            ["device", "name"]
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
        case .delay:
            ["audio", "out", "delay"]
        case .identify:
            ["device", "identification", "visual"]
        case .eq(_, let n, let p):
            ["audio", "out", n, p.finalPathComponent()]
        }
    }

    private func getPathObject() -> any KHStatePathProtocol {
        return switch self {
        case .name: KHStatePath(\.name)
        case .volume: KHStatePath(\.volume)
        case .muted: KHStatePath(\.muted)
        case .logoBrightness: KHStatePath(\.logoBrightness)
        case .standbyEnabled: KHStatePath(\.standbyEnabled)
        case .standbyTimeout: KHStatePath(\.standbyTimeout)
        case .delay: KHStatePath(\.delay)
        case .identify: KHStatePath(\.identify)
        case .eq(let i, _, let p):
            switch p {
            case .boost: KHStatePath(\.eqs[i].boost)
            case .enabled: KHStatePath(\.eqs[i].enabled)
            case .frequency: KHStatePath(\.eqs[i].frequency)
            case .gain: KHStatePath(\.eqs[i].gain)
            case .q: KHStatePath(\.eqs[i].q)
            case .type: KHStatePath(\.eqs[i].type)
            }
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

    func allEqual(_ states: [KHState]) -> Bool { getPathObject().allEqual(states) }
}

enum KHParameterGroup {
    case fetch, send

    func parameters(_ deviceModel: DeviceModel) -> [SSCParameter] {
        switch self {
        case .fetch:
            deviceModel.allParameters()
        case .send:
            deviceModel.allParameters().filter { $0 != .name }
        }
    }
}
