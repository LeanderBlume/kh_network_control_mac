//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

enum KeyPathType<T> {
    case number(WritableKeyPath<T, Double>)
    case string(WritableKeyPath<T, String>)
    case bool(WritableKeyPath<T, Bool>)
    case arrayNumber(WritableKeyPath<T, [Double]>)
    case arrayString(WritableKeyPath<T, [String]>)
    case arrayBool(WritableKeyPath<T, [Bool]>)
}

struct SSCParameter {
    let name: String
    let keyPath: KeyPathType<KHState>
    let devicePath: [String]

    private enum ValueType: Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case arrayString([String])
        case arrayNumber([Double])
        case arrayBool([Bool])
    }

    private func get(from state: KHState) -> ValueType {
        switch keyPath {
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

    private func set(
        value: ValueType,
        into state: KHState,
    ) -> KHState {
        var newState = state
        switch value {
        case .number(let value):
            switch keyPath {
            case .number(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .string(let value):
            switch keyPath {
            case .string(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .bool(let value):
            switch keyPath {
            case .bool(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayNumber(let value):
            switch keyPath {
            case .arrayNumber(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayBool(let value):
            switch keyPath {
            case .arrayBool(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayString(let value):
            switch keyPath {
            case .arrayString(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        }
        return newState
    }

    func fetch(into state: KHState, connection: SSCConnection) async throws -> KHState {
        var v: ValueType
        switch keyPath {
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
        switch keyPath {
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

class KHDevice {
    var state: KHState = KHState()
    let parameterTree: SSCNode
    let connection: SSCConnection

    private let parameters: [SSCParameter] = [
        .init(
            name: "Volume",
            keyPath: .number(\.volume),
            devicePath: ["audio", "out", "level"]
        ),
        .init(
            name: "Muted",
            keyPath: .bool(\.muted),
            devicePath: ["audio", "out", "mute"]
        ),
        .init(
            name: "Logo brightness",
            keyPath: .number(\.logoBrightness),
            devicePath: ["ui", "logo", "brightness"]
        ),

        .init(
            name: "EQ 1 Boost",
            keyPath: .arrayNumber(\.eqs[0].boost),
            devicePath: ["audio", "out", "eq2", "boost"]
        ),
        .init(
            name: "EQ 1 Enabled",
            keyPath: .arrayBool(\.eqs[0].enabled),
            devicePath: ["audio", "out", "eq2", "enabled"]
        ),
        .init(
            name: "EQ 1 Frequency",
            keyPath: .arrayNumber(\.eqs[0].frequency),
            devicePath: ["audio", "out", "eq2", "frequency"]
        ),
        .init(
            name: "EQ 1 Makeup",
            keyPath: .arrayNumber(\.eqs[0].gain),
            devicePath: ["audio", "out", "eq2", "gain"]
        ),
        .init(
            name: "EQ 1 Q",
            keyPath: .arrayNumber(\.eqs[0].q),
            devicePath: ["audio", "out", "eq2", "q"]
        ),
        .init(
            name: "EQ 1 Type",
            keyPath: .arrayString(\.eqs[0].type),
            devicePath: ["audio", "out", "eq2", "type"]
        ),

        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayNumber(\.eqs[1].boost),
            devicePath: ["audio", "out", "eq3", "boost"]
        ),
        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayBool(\.eqs[1].enabled),
            devicePath: ["audio", "out", "eq3", "enabled"]
        ),
        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayNumber(\.eqs[1].frequency),
            devicePath: ["audio", "out", "eq3", "frequency"]
        ),
        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayNumber(\.eqs[1].gain),
            devicePath: ["audio", "out", "eq3", "gain"]
        ),
        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayNumber(\.eqs[1].q),
            devicePath: ["audio", "out", "eq3", "q"]
        ),
        .init(
            name: "EQ 2 Boost",
            keyPath: .arrayString(\.eqs[1].type),
            devicePath: ["audio", "out", "eq3", "type"]
        ),
    ]

    init(connection connection_: SSCConnection) {
        connection = connection_
        parameterTree = SSCNode(connection: connection, name: "root")
    }

    private func connect() async throws {
        try await connection.open()
    }

    private func disconnect() {
        connection.close()
    }

    func populateParameters() async throws {
        try await connect()
        try await parameterTree.populate(recursive: true)
        disconnect()
    }

    func fetch() async throws {
        try await connect()
        for p in parameters {
            state = try await p.fetch(into: state, connection: connection)
        }
        disconnect()
    }

    func send(_ newState: KHState) async throws {
        if newState == state {
            // don't even connect
            return
        }
        try await connect()
        for p in parameters {
            try await p.send(
                oldState: state,
                newState: newState,
                connection: connection
            )
        }
        state = newState
        disconnect()
    }
}
