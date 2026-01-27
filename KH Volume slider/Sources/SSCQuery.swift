//
//  SSCQuery.swift
//  KH Volume slider
//
//  Created by Leander Blume on 19.12.25.
//

import Foundation

enum NodeData {
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

    func isLeaf() -> Bool {
        switch self {
        case .value, .error, .unknownValue:
            return true
        default:
            return false
        }
    }
}

struct OSCLimits: Equatable, Codable {
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

    var isWriteable: Bool { !(writeable == false || const == true) }

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
class SSCNode: Identifiable, @MainActor Sequence {
    var name: String
    var parent: SSCNode?
    var value: NodeData
    var limits: OSCLimits?
    // Maybe this is better than the default ObjectIdentifier. But I don't think so.
    // let id = UUID()

    init(
        name name_: String,
        parent parent_: SSCNode?,
        value value_: NodeData = .unknown,
        limits limits_: OSCLimits? = nil,
    ) {
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

    func getPathString() -> String { "/" + pathToNode().joined(separator: "/") }

    private func queryAux(connection: SSCConnection, query: [String], path: [String])
        async throws -> [String: Any]
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

    func getSchema(
        connection: SSCConnection,
        path: [String]
    ) async throws -> [String: [String: String]?]? {
        var result = try await queryAux(
            connection: connection,
            query: ["osc", "schema"],
            path: path
        )
        if path.isEmpty {
            return result as? [String: [String: String]?]
        }
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        return result[path.last!] as? [String: [String: String]?]
    }

    func getLimits(connection: SSCConnection, path: [String]) async throws -> OSCLimits
    {
        var result = try await queryAux(
            connection: connection,
            query: ["osc", "limits"],
            path: path
        )
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        let result_ = result[path.last!] as! [[String: Any?]]
        let result__ = result_[0]
        return OSCLimits(fromDict: result__)
    }

    private func populateLeaf(connection: SSCConnection) async throws {
        let path = pathToNode()
        limits = try await getLimits(connection: connection, path: path)
        let decoder = JSONDecoder()
        var schemata: [JSONData]
        switch limits!.type {
        case "Number":
            schemata = [.number(0), .array([.number(0)])]
        case "String":
            schemata = [.string(""), .array([.string("")])]
        case "Boolean":
            schemata = [.bool(false), .array([.bool(false)])]
        case .none:
            schemata = [
                .bool(false),
                .number(0),
                .string(""),
                .array([.bool(false)]),
                .array([.number(0)]),
                .array([.string("")]),
            ]
        default:
            throw SSCNodeError.unknownTypeFromLimits(limits!.type)
        }
        let data = try await connection.fetchSSCValueData(path: path)
        for schema in schemata {
            if let v = try? decoder.decode(
                JSONData.self,
                from: data,
                configuration: schema.wrap(in: path)
            ) {
                value = .value(v.unwrap())
                return
            }
        }
        value = .error("Populating leaf fell through")
    }

    private func populateInternal(connection: SSCConnection) async throws {
        // We are not at a leaf node and need to discover subcommands.
        guard
            let resultStripped = try await getSchema(
                connection: connection,
                path: pathToNode()
            )
        else {
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
            subNodeArray.append(SSCNode(name: k, parent: self, value: subNodeValue))
        }
        value = .children(subNodeArray)
    }

    func populate(connection: SSCConnection, recursive: Bool = true) async throws {
        // Populates the tree. Does not refresh previously fetched values!
        // print("populating", pathToNode())
        switch value {
        // Technically bad. We should try to find out if there is a subvalue or
        // children, even for the root node.
        case .unknown, .unknownChildren:
            try await populateInternal(connection: connection)
            try await populate(connection: connection, recursive: recursive)
        case .children(let subNodeArray):
            if recursive {
                for n in subNodeArray {
                    try await n.populate(connection: connection, recursive: true)
                }
            }
        case .unknownValue:
            try await populateLeaf(connection: connection)
        case .value, .error:
            return
        }
    }

    func populate(jsonDataCodable: JSONDataCodable) {
        switch jsonDataCodable {
        case .null:
            value = .error("null")
        case .number(_, let l), .bool(_, let l), .string(_, let l), .array(_, let l):
            value = .value(JSONData(jsonDataCodable: jsonDataCodable))
            limits = l
        case .object(let dict):
            var children: [SSCNode] = []
            for k in dict.keys {
                let child = SSCNode(name: k, parent: self)
                child.populate(jsonDataCodable: dict[k]!)
                children.append(child)
            }
            value = .children(children)
        }
    }

    func isPopulated(recursive: Bool = true) -> Bool {
        switch value {
        case .unknown, .unknownValue, .unknownChildren:
            return false
        case .value, .error:
            return true
        case .children(let children):
            if recursive {
                return children.allSatisfy({ $0.isPopulated(recursive: true) })
            }
            return true
        }
    }

    func send(connection: SSCConnection) async throws {
        switch value {
        case .error:
            return
        case .value(let T):
            try await connection.sendSSCValue(path: pathToNode(), value: T)
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw SSCNodeError.error("Node is not a populated leaf")
        }
    }

    func fetch(connection: SSCConnection) async throws {
        switch value {
        case .error:
            return
        case .value(let T):
            value = .value(
                try await connection.fetchJSONData(path: pathToNode(), type: T)
            )
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw SSCNodeError.error("Node is not a populated leaf")
        }
    }

    // populates leaf nodes in subtree with data from the JSONData object. Assumes node
    // tree is already populated and that the node tree structure is a subtree of the
    // JSONData tree. Value-bearing Leaf nodes will assign data at path, no
    // questions asked.
    func load(jsonData: JSONData) throws {
        switch value {
        case .unknown, .unknownValue, .unknownChildren:
            throw SSCNodeError.error(
                "Node tree must be populated to load from JSONData"
            )
        case .error:
            return
        case .value:
            value = .value(jsonData)
        case .children(let children):
            guard case .object(let dictionary) = jsonData else {
                throw SSCNodeError.error("JSONData structure children/object mismatch")
            }
            try children.forEach({ child in
                if let subData = dictionary[child.name] {
                    try child.load(jsonData: subData)
                } else {
                    throw SSCNodeError.error("No value in data for \(child.name)")
                }
            })
        }
    }

    func load(jsonDataCodable: JSONDataCodable) throws {
        try load(jsonData: JSONData(jsonDataCodable: jsonDataCodable))
    }

    /// Returns list of child nodes, if there are any. This is for SSCTreeView lazy loading. Maybe we don't need this.
    var children: [SSCNode]? {
        if case .children(let c) = value {
            return c.sorted { a, b in
                if a.value.isLeaf() && !b.value.isLeaf() { return true }
                if !a.value.isLeaf() && b.value.isLeaf() { return false }
                return a.name < b.name
            }
        }
        return nil
    }

    func makeIterator() -> [SSCNode].Iterator {
        if case .children(let v) = value {
            return v.flatMap({ child in
                [child] + child.makeIterator()
            }).makeIterator()
        }
        return [].makeIterator()
    }

    subscript(index: String) -> SSCNode? {
        if case .children(let v) = value {
            return v.first(where: { $0.name == index })
        }
        return nil
    }
}
