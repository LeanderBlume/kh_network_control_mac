//
//  Untitled.swift
//  KH Volume slider
//
//  Created by Leander Blume on 10.01.26.
//

import SwiftUI

@Observable
@MainActor
class KHDevice: Identifiable {
    var state: KHState = KHState()
    let parameterTree: SSCNode
    let connection: SSCConnection

    private let fetchParameters = KHParameterCategories.fetchParameters.map({
        SSCParameter(parameter: $0)
    })
    private let sendParameters = KHParameterCategories.sendParameters.map({
        SSCParameter(parameter: $0)
    })
    private let setupParameters = KHParameterCategories.setupParameters.map({
        SSCParameter(parameter: $0)
    })

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

    func setup() async throws {
        try await connect()
        for p in setupParameters {
            state = try await p.fetch(into: state, connection: connection)
        }
        try await fetch()
        disconnect()
    }

    func fetch() async throws {
        try await connect()
        for p in fetchParameters {
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
        for p in sendParameters {
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
