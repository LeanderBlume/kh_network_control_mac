//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

struct KHDevice {
    var state: KHState = KHState()
    let parameters: SSCNode
    private let connection: SSCConnection

    init(connection c_: SSCConnection) {
        connection = c_
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

    mutating func fetch() async throws {
        try await connect()
        state.volume = try await connection.fetchSSCValue(path: [
            "audio", "out", "level",
        ])
        state.muted = try await connection.fetchSSCValue(path: ["audio", "out", "mute"])
        state.logoBrightness = try await connection.fetchSSCValue(path: [
            "ui", "logo", "brightness",
        ])
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            state.eqs[eqIdx].boost = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "boost",
            ])
            state.eqs[eqIdx].enabled = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "enabled",
            ])
            state.eqs[eqIdx].frequency = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "frequency",
            ])
            state.eqs[eqIdx].gain = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "gain",
            ])
            state.eqs[eqIdx].q = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "q",
            ])
            state.eqs[eqIdx].type = try await connection.fetchSSCValue(path: [
                "audio", "out", eqName, "type",
            ])
        }
        disconnect()
    }

    mutating func send(_ newState: KHState) async throws {
        if newState == state {
            return
        }
        try await connect()
        if state.volume != newState.volume {
            try await connection.sendSSCValue(
                path: ["audio", "out", "level"],
                value: newState.volume
            )
        }
        if state.muted != newState.muted {
            try await connection.sendSSCValue(
                path: ["audio", "out", "mute"],
                value: newState.muted
            )
        }
        if state.logoBrightness != newState.logoBrightness {
            try await connection.sendSSCValue(
                path: ["ui", "logo", "brightness"],
                value: newState.logoBrightness
            )
        }
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            if state.eqs[eqIdx].boost != newState.eqs[eqIdx].boost {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "boost"],
                    value: newState.eqs[eqIdx].boost
                )
            }
            if state.eqs[eqIdx].enabled != newState.eqs[eqIdx].enabled {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "enabled"],
                    value: newState.eqs[eqIdx].enabled
                )
            }
            if state.eqs[eqIdx].frequency != newState.eqs[eqIdx].frequency {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "frequency"],
                    value: newState.eqs[eqIdx].frequency
                )
            }
            if state.eqs[eqIdx].gain != newState.eqs[eqIdx].gain {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "gain"],
                    value: newState.eqs[eqIdx].gain
                )
            }
            if state.eqs[eqIdx].q != newState.eqs[eqIdx].q {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "q"],
                    value: newState.eqs[eqIdx].q
                )
            }
            if state.eqs[eqIdx].type != newState.eqs[eqIdx].type {
                try await connection.sendSSCValue(
                    path: ["audio", "out", eqName, "type"],
                    value: newState.eqs[eqIdx].type
                )
            }
        }
        state = newState
        disconnect()
    }
}
