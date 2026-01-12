//
//  SSCQuery.swift
//  KH Volume slider
//
//  Created by Leander Blume on 19.12.25.
//

import Foundation

enum NodeData: Equatable {
    case unknown
    case unknownChildren
    case unknownValue
    case children([SSCNode])
    case value(JSONData)
    case error(String)

    init(value: String) { self = .value(.string(value)) }
    init(value: Double) { self = .value(.number(value)) }
    init(value: Bool) { self = .value(.bool(value)) }
    init(value: [String]) { self = .value(.array(value.map({ .string($0) }))) }
    init(value: [Double]) { self = .value(.array(value.map({ .number($0) }))) }
    init(value: [Bool]) { self = .value(.array(value.map({ .bool($0) }))) }

    func isUnknown() -> Bool {
        switch self {
        case .unknown, .unknownChildren, .unknownValue:
            return true
        default:
            return false
        }
    }
}

struct OSCLimits: Equatable {
    let type: String?
    let units: String?
    let max: Double?
    let min: Double?
    let inc: Double?
    let subscr: Bool?
    let const: Bool?
    let desc: String?
    let writeable: Bool?
    let option: [String]?
    let count: Int?

    init(fromDict dict: [String: Any?]) {
        type = dict["type"] as? String
        units = dict["units"] as? String
        max = dict["max"] as? Double
        min = dict["min"] as? Double
        inc = dict["inc"] as? Double
        subscr = dict["subscr"] as? Bool
        const = dict["const"] as? Bool
        desc = dict["desc"] as? String
        writeable = dict["writeable"] as? Bool
        option = dict["option"] as? [String]
        count = dict["count"] as? Int
    }
}

enum SSCNodeError: Error {
    case malformedResponse(String)
    case unknownTypeFromLimits(String?)
    case error(String)
}

@Observable
@MainActor
class SSCNode: Identifiable, Equatable {
    private var connection: SSCConnection
    var name: String
    var value: NodeData
    var parent: SSCNode?
    var limits: OSCLimits?
    // Maybe this is better than the default ObjectIdentifier. But I don't think so.
    // let id = UUID()

    init(
        connection connection_: SSCConnection,
        name name_: String,
        value value_: NodeData = .unknown,
        parent parent_: SSCNode? = nil,
        limits limits_: OSCLimits? = nil,
    ) {
        connection = connection_
        name = name_
        value = value_
        parent = parent_
        limits = limits_
    }

    func rootNode() -> SSCNode {
        var curr: SSCNode = self
        while curr.parent != nil {
            curr = parent!
        }
        return curr
    }

    func pathToNode() -> [String] {
        var result: [String] = []
        var curr: SSCNode? = self
        while curr != nil {
            result.append(curr!.name)
            curr = curr!.parent
        }
        // The root node doesn't have a name, so we drop it.
        return result.dropLast().reversed()
    }

    private func queryAux(query: [String], path: [String]) async throws -> [String: Any]
    {
        // Queries device with
        // {query[0]: { ... { query[-1]: [ pathToNode() ] } ... }
        // and returns unwrapped result.
        // In reality, query will be either ["osc", "schema"] or ["osc", "limits"].
        var pathString = try SSCConnection.pathToJSONString(
            path: path,
            value: nil as String?
        )
        if !path.isEmpty {
            pathString = "[" + pathString + "]"
        }
        var queryCommand = pathString
        for p in query.reversed() {
            queryCommand = "{\"\(p)\":\(queryCommand)}"
        }
        let response: String = try await connection.sendSSCCommand(
            command: queryCommand
        )
        guard let data = response.data(using: .utf8) else {
            throw SSCNodeError.error("No data from response")
        }
        let result =
            try JSONSerialization.jsonObject(with: data, options: [])
            as! [String: [String: [[String: Any]]]]
        return result[query[0]]![query[1]]![0]
    }

    func getSchema(path: [String]) async throws -> [String: [String: String]?]? {
        var result = try await queryAux(query: ["osc", "schema"], path: path)
        if path.isEmpty {
            return result as? [String: [String: String]?]
        }
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        return result[path.last!] as? [String: [String: String]?]
    }

    func getLimits(path: [String]) async throws -> OSCLimits {
        var result = try await queryAux(query: ["osc", "limits"], path: path)
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        let result_ = result[path.last!] as! [[String: Any?]]
        let result__ = result_[0]
        return OSCLimits(fromDict: result__)
    }

    private func populateLeaf() async throws {
        let path = pathToNode()
        limits = try await getLimits(path: path)
        let response = try await connection.fetchSSCValueAny(path: path)
        // print(response)
        // In theory: Count is given => array type
        // But this is often wrong. There are various values with no count given at all
        // that are actually arrays. So we just try both single values and arrays.
        switch limits!.type {
        case "Number":
            if let v = response as? Double {
                value = NodeData(value: v)
            } else if let v = response as? [Double] {
                value = NodeData(value: v)
            }
        case "String":
            if let v = response as? String {
                value = NodeData(value: v)
            } else if let v = response as? [String] {
                value = NodeData(value: v)
            }
        case "Boolean":
            if let v = response as? Bool {
                value = NodeData(value: v)
            } else if let v = response as? [Bool] {
                value = NodeData(value: v)
            }
        case nil:
            // Limits did not return a type, so We just try all types.
            // This does not work on its own. true/false and 0/1 can be converted into
            // each other so we will always get wrong results somewhere.
            // Can we use the "is" keyword?
            if let v = response as? Bool {
                value = NodeData(value: v)
            } else if let v = response as? Double {
                value = NodeData(value: v)
            } else if let v = response as? String {
                value = NodeData(value: v)
            } else if let v = response as? [Bool] {
                value = NodeData(value: v)
            } else if let v = response as? [Double] {
                value = NodeData(value: v)
            } else if let v = response as? [String] {
                value = NodeData(value: v)
            } else {
                value = .error("Unknown type")
            }
        default:
            throw SSCNodeError.unknownTypeFromLimits(limits!.type)
        }
    }

    private func fetchLeaf() async throws {
        // this once again seems dumb. I don't know if there's a better way.
        let path = pathToNode()
        switch value {
        case .error:
            return
        case .value(let T):
            value = .value(try await T.fetch(connection: connection, path: path))
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw SSCNodeError.error("Not a populated leaf")
        }
    }
    
    private func sendLeaf() async throws {
        let path = pathToNode()
        switch value {
        case .error:
            return
        case .value(let T):
            try await connection.sendSSCValue(path: path, value: T)
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw SSCNodeError.error("Not a populated leaf")
        }
    }

    private func populateInternal() async throws {
        // We are not at a leaf node and need to discover subcommands.
        guard let resultStripped = try await getSchema(path: pathToNode()) else {
            throw SSCNodeError.error(
                "Populating internal node did not result in a sub-dictionary."
            )
        }
        var subNodeArray: [SSCNode] = []
        for (k, v) in resultStripped {
            let subNodeValue: NodeData
            if v == nil {
                subNodeValue = .unknownValue
            } else if v == [:] {
                subNodeValue = .unknownChildren
            } else {
                throw SSCNodeError.malformedResponse(
                    String(describing: v) + " is neither null nor {}."
                )
            }
            subNodeArray.append(
                SSCNode(
                    connection: self.connection,
                    name: k,
                    value: subNodeValue,
                    parent: self
                )
            )
        }
        subNodeArray.sort { a, b in
            // We want to put non-objects first.
            if a.value == .unknownValue && b.value == .unknownChildren {
                return true
            }
            if a.value == .unknownChildren && b.value == .unknownValue {
                return false
            }
            return a.name < b.name
        }
        value = .children(subNodeArray)
    }

    func populate(recursive: Bool = true) async throws {
        // Populates the tree. Does not refresh previously fetched values!
        // print("populating", pathToNode())
        switch value {
        // Technically bad. We should try to find out if there is a subvalue or
        // children, even for the root node.
        case .unknown, .unknownChildren:
            try await populateInternal()
            try await populate(recursive: recursive)
        case .children(let subNodeArray):
            if recursive {
                for n in subNodeArray {
                    try await n.populate()
                }
            }
        case .unknownValue:
            try await populateLeaf()
        case .value:
            try await fetchLeaf()
        case .error:
            return
        }
    }

    /// Returns list of child nodes, if there are any. This is for SSCTreeView lazy loading. Maybe we don't need this.
    var children: [SSCNode]? {
        // We need a better way to rate-limit this
        /*
        if value == nil {
            Task {
                try await Task.sleep(nanoseconds: 1_000_000)
                try await populate(recursive: false)
            }
        }
         */
        if case .children(let c) = value {
            return c
        }
        return nil
    }

    nonisolated static func == (lhs: SSCNode, rhs: SSCNode) -> Bool {
        return (lhs.id == rhs.id)
    }
}
