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

private protocol StateParameterBridgeProtocol {
    // associatedtype T: Equatable, Codable, Sendable
    // var keyPath: WritableKeyPath<KHState, T> { get }

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

private struct StateParameterBridge<
    TState: Codable & Equatable & Sendable,
    TDevice: Codable & Sendable
>:
    StateParameterBridgeProtocol
{
    let keyPath: WritableKeyPath<KHState, TState>
    let UIToDevice: (TState, TDevice) -> TDevice
    let deviceToUI: (TState, TDevice) -> TState

    init(
        _ keyPath: WritableKeyPath<KHState, TState>,
        UIToDevice: @escaping (TState, TDevice) -> TDevice = { _, d in d },
        deviceToUI: @escaping (TState, TDevice) -> TState = { s, _ in s }
    ) {
        self.keyPath = keyPath
        self.UIToDevice = UIToDevice
        self.deviceToUI = deviceToUI
    }

    private func get(from state: KHState) -> TState {
        state[keyPath: keyPath]
    }

    private func get(from jsonData: JSONData) -> TDevice? {
        switch jsonData {
        case .array:
            jsonData.asArrayAny() as? TDevice
        default:
            jsonData.asAny() as? TDevice
        }
    }

    private func set(_ value: TState, into state: KHState) -> KHState {
        var newState = state
        newState[keyPath: keyPath] = value
        return newState
    }

    private func set(_ jsonData: JSONData, into state: KHState) -> KHState? {
        guard let value = get(from: jsonData) else { return nil }
        let converted = deviceToUI(state[keyPath: keyPath], value)
        return set(converted, into: state)
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
        let newValue: TDevice = try await connection.fetchSSCValue(path: devicePath)
        var newState = state
        newState[keyPath: keyPath] = deviceToUI(state[keyPath: keyPath], newValue)
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
    case boost
    case enabled
    case frequency
    case gain
    case q
    case type

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
    case name
    case volume
    case muted
    case logoBrightness
    case standbyEnabled
    case standbyTimeout
    case delay
    case identify
    case eq(
        _ eqIndex: Int,
        _ bandIndex: Int,
        _ eqName: String,
        _ eqParameter: EQParameter
    )

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
        for (i, name, numBands) in [(0, "eq2", 10), (1, "eq3", 20)] {
            for band in 0..<numBands {
                for p in EQParameter.allCases {
                    result.append(.eq(i, band, name, p))
                }
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
        case .eq(let i, let b, _, let p): "EQ \(i + 1) band \(b + 1) \(p.description())"
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
        case .eq(_, _, let n, let p):
            ["audio", "out", n, p.finalPathComponent()]
        }
    }

    private func getPathObject() -> any StateParameterBridgeProtocol {
        return switch self {
        case .name:
            StateParameterBridge<String, String>(\.name)
        case .volume:
            StateParameterBridge<Double, Double>(\.volume)
        case .muted:
            StateParameterBridge<Bool, Bool>(\.muted)
        case .logoBrightness:
            StateParameterBridge<Double, Double>(\.logoBrightness)
        case .standbyEnabled:
            StateParameterBridge<Bool, Bool>(\.standbyEnabled)
        case .standbyTimeout:
            StateParameterBridge<Double, Double>(\.standbyTimeout)
        case .delay:
            StateParameterBridge<Double, Double>(\.delay)
        case .identify:
            StateParameterBridge<Bool, Bool>(\.identify)
        case .eq(let i, let b, _, let p):
            switch p {
            case .boost:
                StateParameterBridge<Double, [Double]>(
                    \.eqs[i].boost[b],
                     UIToDevice: { v, A in
                         var newA = A
                         newA.insert(v, at: b)
                         return newA
                     }
                )
            case .enabled:
                StateParameterBridge<Bool, [Bool]>(\.eqs[i].enabled[b])
            case .frequency:
                StateParameterBridge<Double, [Double]>(\.eqs[i].frequency[b])
            case .gain:
                StateParameterBridge<Double, [Double]>(\.eqs[i].gain[b])
            case .q:
                StateParameterBridge<Double, [Double]>(\.eqs[i].q[b])
            case .type:
                StateParameterBridge<String, [String]>(\.eqs[i].type[b])
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
    case fetch
    case send

    func parameters(_ deviceModel: DeviceModel) -> [SSCParameter] {
        switch self {
        case .fetch:
            deviceModel.allParameters()
        case .send:
            deviceModel.allParameters().filter { $0 != .name }
        }
    }
}
