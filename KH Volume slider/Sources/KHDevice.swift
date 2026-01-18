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

    enum KHDeviceError: Error {
        case error(String)
    }

    private let fetchParameters = KHParameters.fetchParameters.map({
        SSCParameter(parameter: $0)
    })
    private let sendParameters = KHParameters.sendParameters.map({
        SSCParameter(parameter: $0)
    })
    private let setupParameters = KHParameters.setupParameters.map({
        SSCParameter(parameter: $0)
    })

    init(connection connection_: SSCConnection) {
        connection = connection_
        parameterTree = SSCNode(name: "root")
    }

    private func connect() async throws {
        try await connection.open()
    }

    private func disconnect() {
        connection.close()
    }

    func populateParameters() async throws {
        try await connect()
        try await parameterTree.populate(connection: connection, recursive: true)
        disconnect()
    }

    func fetchParameters() async throws {
        try await connect()
        for node in parameterTree {
            if case .value = node.value {
                try await fetchSingleNode(node: node)
            }
        }
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

    private func getNode(atPath path: [String]) -> SSCNode? {
        var node: SSCNode? = parameterTree
        for p in path {
            node = node![p]
            if node == nil {
                return nil
            }
        }
        return node
    }

    private func sendSingleNode(node: SSCNode) async throws {
        switch node.value {
        case .error:
            return
        case .value(let T):
            try await connection.sendSSCValue(path: node.pathToNode(), value: T)
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw KHDeviceError.error("Node is not a populated leaf")
        }
    }

    private func fetchSingleNode(node: SSCNode) async throws {
        switch node.value {
        case .error:
            return
        case .value(let T):
            node.value = .value(
                try await T.fetch(connection: connection, path: node.pathToNode())
            )
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw KHDeviceError.error("Node is not a populated leaf")
        }
    }

    func sendNode(_ path: [String]) async throws {
        guard let node = getNode(atPath: path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await sendSingleNode(node: node)
        disconnect()
    }

    func fetchNode(_ path: [String]) async throws {
        guard let node = getNode(atPath: path) else {
            throw KHDeviceError.error("Node not found")
        }
        try await connect()
        try await fetchSingleNode(node: node)
        disconnect()
    }
}
