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
            let keyPath = parameter.getKeyPath()
            switch (keyPath, valAtPath) {
            case (.bool(let p), .bool(let v)):
                self[keyPath: p] = v
            case (.number(let p), .number(let v)):
                self[keyPath: p] = v
            case (.string(let p), .string(let v)):
                self[keyPath: p] = v
            case (.arrayBool(let p), .array):
                guard let v = valAtPath.asArrayBool() else { break }
                self[keyPath: p] = v
            case (.arrayNumber(let p), .array):
                guard let v = valAtPath.asArrayNumber() else { break }
                self[keyPath: p] = v
            case (.arrayString(let p), .array):
                guard let v = valAtPath.asArrayString() else { break }
                self[keyPath: p] = v
            default: break
            }
        }
    }

    init?(jsonDataCodable: JSONDataCodable) {
        self.init(jsonData: JSONData(jsonDataCodable: jsonDataCodable))
    }
}

enum KeyPathType<T> {
    case number(WritableKeyPath<T, Double>)
    case string(WritableKeyPath<T, String>)
    case bool(WritableKeyPath<T, Bool>)
    case arrayNumber(WritableKeyPath<T, [Double]>)
    case arrayString(WritableKeyPath<T, [String]>)
    case arrayBool(WritableKeyPath<T, [Bool]>)
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
    static let setupParameters: [KHParameters] = [.name, .serial, .product, .version]

    private func get(from state: KHState) -> JSONDataSimple {
        JSONDataSimple(state: state, keyPath: getKeyPath())
    }

    private func set(value: JSONDataSimple, into state: KHState) -> KHState {
        value.set(into: state, keyPath: getKeyPath())
    }

    func copy(from sourceState: KHState, into targetState: KHState) -> KHState {
        set(value: get(from: sourceState), into: targetState)
    }

    func getKeyPath() -> KeyPathType<KHState> {
        switch self {
        case .name:
            .string(\.name)
        case .serial:
            .string(\.serial)
        case .product:
            .string(\.product)
        case .version:
            .string(\.version)
        case .volume:
            .number(\.volume)
        case .muted:
            .bool(\.muted)
        case .logoBrightness:
            .number(\.logoBrightness)

        case .eq0boost:
            .arrayNumber(\.eqs[0].boost)
        case .eq0enabled:
            .arrayBool(\.eqs[0].enabled)
        case .eq0frequency:
            .arrayNumber(\.eqs[0].frequency)
        case .eq0gain:
            .arrayNumber(\.eqs[0].gain)
        case .eq0q:
            .arrayNumber(\.eqs[0].q)
        case .eq0type:
            .arrayString(\.eqs[0].type)
        case .eq1boost:
            .arrayNumber(\.eqs[1].boost)
        case .eq1enabled:
            .arrayBool(\.eqs[1].enabled)
        case .eq1frequency:
            .arrayNumber(\.eqs[1].frequency)
        case .eq1gain:
            .arrayNumber(\.eqs[1].gain)
        case .eq1q:
            .arrayNumber(\.eqs[1].q)
        case .eq1type:
            .arrayString(\.eqs[1].type)
        }
    }

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

    func getDevicePath() -> [String] {
        let fallback = getDevicePathFallback()
        guard let pathDict = KHParameters.getPathDict() else {
            return fallback
        }
        return pathDict[rawValue] ?? fallback
    }

    func getPathString() -> String { "/" + getDevicePath().joined(separator: "/") }

    static func devicePathDictDefault() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for p in KHParameters.allCases {
            result[p.rawValue] = p.getDevicePathFallback()
        }
        return result
    }

    func setDevicePath(to path: [String]) {
        guard var dict = KHParameters.getPathDict() else {
            return
        }
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

    func fetch(into state: KHState, connection: SSCConnection) async throws -> KHState {
        var v: JSONDataSimple
        let devicePath = getDevicePath()
        switch getKeyPath() {
        case .number:
            v = .number(try await connection.fetchSSCValue(path: devicePath))
        case .bool:
            v = .bool(try await connection.fetchSSCValue(path: devicePath))
        case .string:
            v = .string(try await connection.fetchSSCValue(path: devicePath))
        case .arrayBool:
            v = .arrayBool(try await connection.fetchSSCValue(path: devicePath))
        case .arrayNumber:
            v = .arrayNumber(try await connection.fetchSSCValue(path: devicePath))
        case .arrayString:
            v = .arrayString(try await connection.fetchSSCValue(path: devicePath))
        }
        return set(value: v, into: state)
    }

    func send(oldState: KHState, newState: KHState, connection: SSCConnection)
        async throws
    {
        if get(from: oldState) == get(from: newState) {
            return
        }
        let devicePath = getDevicePath()
        switch getKeyPath() {
        case .number(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        case .string(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        case .bool(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        case .arrayNumber(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        case .arrayBool(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        case .arrayString(let keyPath):
            try await connection.sendSSCValue(
                path: devicePath,
                value: newState[keyPath: keyPath]
            )
        }
    }
}
