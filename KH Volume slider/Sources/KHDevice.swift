//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

// These enums are wacky as hell
enum ValueType: Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case arrayString([String])
    case arrayNumber([Double])
    case arrayBool([Bool])

    func send(connection: SSCConnection, path: [String]) async throws {
        switch self {
        case .number(let value):
            try await connection.sendSSCValue(path: path, value: value)
        case .string(let value):
            try await connection.sendSSCValue(path: path, value: value)
        case .bool(let value):
            try await connection.sendSSCValue(path: path, value: value)
        case .arrayNumber(let value):
            try await connection.sendSSCValue(path: path, value: value)
        case .arrayBool(let value):
            try await connection.sendSSCValue(path: path, value: value)
        case .arrayString(let value):
            try await connection.sendSSCValue(path: path, value: value)
        }
    }
    
    func set(into state: inout KHState, at keyPath: KeyPathType<KHState>) {
        switch self {
        case .number(let value):
            switch keyPath {
                case .number(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        case .string(let value):
            switch keyPath {
                case .string(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        case .bool(let value):
            switch keyPath {
                case .bool(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayNumber(let value):
            switch keyPath {
                case .arrayNumber(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayBool(let value):
            switch keyPath {
                case .arrayBool(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayString(let value):
            switch keyPath {
                case .arrayString(let keyPath):
                state[keyPath: keyPath] = value
            default:
                break
            }
        }
    }
}

enum KeyPathType<T> {
    case number(WritableKeyPath<T, Double>)
    case string(WritableKeyPath<T, String>)
    case bool(WritableKeyPath<T, Bool>)
    case arrayNumber(WritableKeyPath<T, [Double]>)
    case arrayString(WritableKeyPath<T, [String]>)
    case arrayBool(WritableKeyPath<T, [Bool]>)

    func get(from state: T) -> ValueType {
        switch self {
        case .number(let keyPath):
            return .number(state[keyPath: keyPath])
        case .bool(let keyPath):
            return .bool(state[keyPath: keyPath])
        case .string(let keyPath):
            return .string(state[keyPath: keyPath])
        case .arrayBool(let keyPath):
            return .arrayBool(state[keyPath: keyPath])
        case .arrayNumber(let keyPath):
            return .arrayNumber(state[keyPath: keyPath])
        case .arrayString(let keyPath):
            return .arrayString(state[keyPath: keyPath])
        }
    }
    
    func fetch(connection: SSCConnection, path: [String]) async throws -> ValueType {
        switch self {
        case .number:
            return .number(try await connection.fetchSSCValue(path: path))
        case .bool:
            return .bool(try await connection.fetchSSCValue(path: path))
        case .string:
            return .string(try await connection.fetchSSCValue(path: path))
        case .arrayBool:
            return .arrayBool(try await connection.fetchSSCValue(path: path))
        case .arrayNumber:
            return .arrayNumber(try await connection.fetchSSCValue(path: path))
        case .arrayString:
            return .arrayString(try await connection.fetchSSCValue(path: path))
        }
    }
}

class KHDevice {
    var state: KHState = KHState()
    let parameters: SSCNode
    let connection: SSCConnection

    private let paths: [(KeyPathType<KHState>, [String])] = [
        (.number(\.volume), ["audio", "out", "level"]),
        (.bool(\.muted), ["audio", "out", "mute"]),
        (.number(\.logoBrightness), ["ui", "logo", "brightness"]),

        (.arrayNumber(\.eqs[0].boost), ["audio", "out", "eq2", "boost"]),
        (.arrayBool(\.eqs[0].enabled), ["audio", "out", "eq2", "enabled"]),
        (.arrayNumber(\.eqs[0].frequency), ["audio", "out", "eq2", "frequency"]),
        (.arrayNumber(\.eqs[0].gain), ["audio", "out", "eq2", "gain"]),
        (.arrayNumber(\.eqs[0].q), ["audio", "out", "eq2", "q"]),
        (.arrayString(\.eqs[0].type), ["audio", "out", "eq2", "type"]),

        (.arrayNumber(\.eqs[1].boost), ["audio", "out", "eq3", "boost"]),
        (.arrayBool(\.eqs[1].enabled), ["audio", "out", "eq3", "enabled"]),
        (.arrayNumber(\.eqs[1].frequency), ["audio", "out", "eq3", "frequency"]),
        (.arrayNumber(\.eqs[1].gain), ["audio", "out", "eq3", "gain"]),
        (.arrayNumber(\.eqs[1].q), ["audio", "out", "eq3", "q"]),
        (.arrayString(\.eqs[1].type), ["audio", "out", "eq3", "type"]),
    ]

    init(connection connection_: SSCConnection) {
        connection = connection_
        parameters = SSCNode(connection: connection, name: "root")
    }

    private func connect() async throws {
        try await connection.open()
    }

    private func disconnect() {
        connection.close()
    }

    func populateParameters() async throws {
        try await connect()
        try await parameters.populate(recursive: true)
        disconnect()
    }

    func fetch() async throws {
        try await connect()
        for (kp, dp) in paths {
            let value = try await kp.fetch(connection: connection, path: dp)
            value.set(into: &state, at: kp)
        }
        disconnect()
    }

    func send(_ newState: KHState) async throws {
        if newState == state {
            return
        }
        try await connect()
        for (kp, dp) in paths {
            if kp.get(from: state) != kp.get(from: newState) {
                let newValue = kp.get(from: newState)
                try await newValue.send(connection: connection, path: dp)
            }
        }
        state = newState
        disconnect()
    }
}
