//
//  KHJSON.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct Eq: Codable, Equatable {
    var desc: String = ""
    var boost: [Double]
    var enabled: [Bool]
    var frequency: [Double]
    var gain: [Double]
    var q: [Double]
    var type: [String]

    init(numBands: Int) {
        boost = Array(repeating: 0.0, count: numBands)
        enabled = Array(repeating: false, count: numBands)
        frequency = Array(repeating: 100.0, count: numBands)
        gain = Array(repeating: 0.0, count: numBands)
        q = Array(repeating: 0.7, count: numBands)
        type = Array(repeating: Eq.EqType.parametric.rawValue, count: numBands)
    }

    enum EqType: String, CaseIterable, Identifiable {
        case parametric = "PARAMETRIC"
        case loshelf = "LOSHELF"
        case hishelf = "HISHELF"
        case lowpass = "LOWPASS"
        case highpass = "HIGHPASS"
        case bandpass = "BANDPASS"
        case notch = "NOTCH"
        case allpass = "ALLPASS"
        case hi6db = "HI6DB"
        case lo6db = "LO6DB"
        case inversion = "INVERSION"

        var id: String { self.rawValue }
    }
}

struct KHState: Codable, Equatable {
    var name = "Unknown name"
    var product = "Unknown model"
    var version = "Unknown version"
    var serial = "Unknown serial"
    var volume = 54.0
    var eqs = [Eq(numBands: 10), Eq(numBands: 20)]
    var muted = false
    var logoBrightness = 100.0

    init() {}

    init?(jsonData: JSONData) {
        for parameter in KHParameters.allCases {
            guard let valAtPath = jsonData.getAtPath(parameter.getDevicePath()) else {
                return nil
            }
            let p = parameter.getPathObject()
            switch valAtPath {
            case .bool(let v):
                guard let pn = p as? KHStatePath<Bool> else { return nil }
                self[keyPath: pn.keyPath] = v
            case .number(let v):
                guard let pn = p as? KHStatePath<Double> else { return nil }
                self[keyPath: pn.keyPath] = v
            case .string(let v):
                guard let pn = p as? KHStatePath<String> else { return nil }
                self[keyPath: pn.keyPath] = v
            case .array:
                if let v = valAtPath.asArrayBool() {
                    guard let pn = p as? KHStatePath<[Bool]> else { return nil }
                    self[keyPath: pn.keyPath] = v
                } else if let v = valAtPath.asArrayNumber() {
                    guard let pn = p as? KHStatePath<[Double]> else { return nil }
                    self[keyPath: pn.keyPath] = v
                } else if let v = valAtPath.asArrayString() {
                    guard let pn = p as? KHStatePath<[String]> else { return nil }
                    self[keyPath: pn.keyPath] = v
                }
            default: return nil
            }
        }
    }

    init?(jsonDataCodable: JSONDataCodable) {
        self.init(jsonData: JSONData(jsonDataCodable: jsonDataCodable))
    }
}

protocol KHStatePathProtocol: Equatable {
    associatedtype T: Equatable, Codable, Sendable

    var keyPath: WritableKeyPath<KHState, T> { get }
    var devicePath: [String] { get }

    // func get(from state: KHState) -> T
    // func set(value: T, into state: KHState) -> KHState
    func copy(from sourceState: KHState, into targetState: KHState) -> KHState
    func fetch(into state: KHState, connection: SSCConnection) async throws -> KHState
    func send(oldState: KHState, newState: KHState, connection: SSCConnection)
        async throws
}

struct KHStatePath<T>: KHStatePathProtocol where T: Equatable, T: Codable, T: Sendable {
    let keyPath: WritableKeyPath<KHState, T>
    let devicePath: [String]

    private func get(from state: KHState) -> T {
        state[keyPath: keyPath]
    }

    private func set(value: T, into state: KHState) -> KHState {
        var newState = state
        newState[keyPath: keyPath] = value
        return newState
    }

    func copy(from sourceState: KHState, into targetState: KHState) -> KHState {
        set(value: get(from: sourceState), into: targetState)
    }

    func fetch(into state: KHState, connection: SSCConnection) async throws -> KHState {
        let newValue: T = try await connection.fetchSSCValue(path: devicePath)
        var newState = state
        newState[keyPath: keyPath] = newValue
        return newState
    }

    func send(oldState: KHState, newState: KHState, connection: SSCConnection)
        async throws
    {
        if oldState[keyPath: keyPath] == newState[keyPath: keyPath] { return }
        try await connection.sendSSCValue(
            path: devicePath,
            value: newState[keyPath: keyPath]
        )
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

    static let fetchParameters: [KHParameters] = [
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
    ]

    static let sendParameters: [KHParameters] = [
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
    ]

    static let setupParameters: [KHParameters] = [
        .name,
        .serial,
        .product,
        .version,
    ]

    private func getDevicePathFallback() -> [String] {
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

    private static func getPathDict() -> [String: [String]]? {
        let decoder = JSONDecoder()
        guard let data: Data = AppStorage("paths").wrappedValue else {
            return nil
        }
        return try? decoder.decode([String: [String]].self, from: data)
    }

    private func _getDevicePath() -> [String] {
        let fallback = getDevicePathFallback()
        guard let pathDict = KHParameters.getPathDict() else {
            return fallback
        }
        return pathDict[rawValue] ?? fallback
    }

    static func devicePathDictDefault() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for p in KHParameters.allCases {
            result[p.rawValue] = p.getDevicePathFallback()
        }
        return result
    }

    func setDevicePath(to path: [String]) {
        guard var dict = KHParameters.getPathDict() else { return }
        dict[rawValue] = path
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(dict) {
            AppStorage("paths").wrappedValue = data
        }
    }

    func resetDevicePath() { setDevicePath(to: getDevicePathFallback()) }

    static func resetAllDevicePaths() {
        KHParameters.allCases.forEach { $0.resetDevicePath() }
    }

    func getPathObject() -> any KHStatePathProtocol {
        switch self {
        case .name:
            KHStatePath(keyPath: \.name, devicePath: _getDevicePath())
        case .serial:
            KHStatePath(keyPath: \.serial, devicePath: _getDevicePath())
        case .product:
            KHStatePath(keyPath: \.product, devicePath: _getDevicePath())
        case .version:
            KHStatePath(keyPath: \.version, devicePath: _getDevicePath())
        case .volume:
            KHStatePath(keyPath: \.volume, devicePath: _getDevicePath())
        case .muted:
            KHStatePath(keyPath: \.muted, devicePath: _getDevicePath())
        case .logoBrightness:
            KHStatePath(keyPath: \.logoBrightness, devicePath: _getDevicePath())

        case .eq0boost:
            KHStatePath(keyPath: \.eqs[0].boost, devicePath: _getDevicePath())
        case .eq0enabled:
            KHStatePath(keyPath: \.eqs[0].enabled, devicePath: _getDevicePath())
        case .eq0frequency:
            KHStatePath(keyPath: \.eqs[0].frequency, devicePath: _getDevicePath())
        case .eq0gain:
            KHStatePath(keyPath: \.eqs[0].gain, devicePath: _getDevicePath())
        case .eq0q:
            KHStatePath(keyPath: \.eqs[0].q, devicePath: _getDevicePath())
        case .eq0type:
            KHStatePath(keyPath: \.eqs[0].type, devicePath: _getDevicePath())

        case .eq1boost:
            KHStatePath(keyPath: \.eqs[1].boost, devicePath: _getDevicePath())
        case .eq1enabled:
            KHStatePath(keyPath: \.eqs[1].enabled, devicePath: _getDevicePath())
        case .eq1frequency:
            KHStatePath(keyPath: \.eqs[1].frequency, devicePath: _getDevicePath())
        case .eq1gain:
            KHStatePath(keyPath: \.eqs[1].gain, devicePath: _getDevicePath())
        case .eq1q:
            KHStatePath(keyPath: \.eqs[1].q, devicePath: _getDevicePath())
        case .eq1type:
            KHStatePath(keyPath: \.eqs[1].type, devicePath: _getDevicePath())
        }
    }
    
    func copy(from sourceState: KHState, into targetState: KHState) -> KHState {
        return getPathObject().copy(from: sourceState, into: targetState)
    }

    func fetch(into state: KHState, connection: SSCConnection) async throws -> KHState {
        try await getPathObject().fetch(into: state, connection: connection)
    }

    func send(oldState: KHState, newState: KHState, connection: SSCConnection)
        async throws
    {
        try await getPathObject().send(
            oldState: oldState,
            newState: newState,
            connection: connection
        )
    }

    func getDevicePath() -> [String] { getPathObject().devicePath }
    func getPathString() -> String { "/" + getDevicePath().joined(separator: "/") }
}
