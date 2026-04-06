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

    func isLeaf() -> Bool {
        switch self {
        case .value, .error:
            return true
        default:
            return false
        }
    }
}

struct OSCLimits: Equatable, Codable {
    let desc: String?
    let type: String?
    let units: String?
    let max: Double?
    let min: Double?
    let inc: Double?
    let subscr: Bool?
    let const: Bool?
    let writeable: Bool?
    let count: Int?
    let option: [String]?

    var isWriteable: Bool { !(writeable == false || const == true) }

    init?(fromJSONObject jd: JSONData) {
        desc = jd["desc"]?.asType()
        type = jd["type"]?.asType()
        units = jd["units"]?.asType()
        max = jd["max"]?.asType()
        min = jd["min"]?.asType()
        inc = jd["inc"]?.asType()
        subscr = jd["subscr"]?.asType()
        const = jd["const"]?.asType()
        writeable = jd["writeable"]?.asType()

        option = jd["option"]?.asArrayType()

        if let countDouble: Double = jd["count"]?.asType() {
            count = Int(countDouble)
        } else {
            count = nil
        }
    }
}

enum SSCNodeError: Error {
    case malformedResponse(String)
    case unknownTypeFromLimits(String?)
    case error(String)
}

@Observable
@MainActor
class SSCNode: @MainActor Identifiable, @MainActor Sequence {
    let name: String
    let deviceID: KHDevice.ID
    let parent: SSCNode?
    var value: NodeData
    var limits: OSCLimits?

    struct NodeID: Hashable, Codable {
        let deviceID: KHDevice.ID
        let path: [String]
    }

    var id: NodeID { .init(deviceID: deviceID, path: pathToNode()) }

    init(
        name: String,
        deviceID: KHDevice.ID,
        parent: SSCNode?,
        value: NodeData = .unknown,
        limits: OSCLimits? = nil,
    ) {
        self.name = name
        self.deviceID = deviceID
        self.value = value
        self.parent = parent
        self.limits = limits
    }

    func isLeaf() -> Bool { value.isLeaf() }

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

    func getAtPath(_ path: [String]) -> SSCNode? {
        var curr = self
        for p in path {
            guard let child = curr[p] else { return nil }
            curr = child
        }
        return curr
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? { first(where: { $0.id == id }) }

    static private func queryAux(
        connection: SSCConnection,
        query: [String],
        path: [String]
    )
        async throws -> JSONData
    {
        // Queries device with
        // {query[0]: { ... { query[-1]: [ pathToNode() ] } ... }
        // and returns unwrapped result.
        // In reality, query will be either ["osc", "schema"] or ["osc", "limits"].
        var pathJD: JSONData = .null.wrap(in: path)
        /// We only want to wrap in an array if there is an actual path. To query the root node, we just send null.
        if !path.isEmpty {
            pathJD = .array([pathJD])
        }
        let queryCommand: JSONData = pathJD.wrap(in: query)
        let response = try await connection.sendJSONData(queryCommand)
        guard case .array(let vs) = response.unwrap() else {
            throw SSCNodeError.error("Malformed response from query")
        }
        guard let first = vs.first else {
            throw SSCNodeError.error("Empty array from query")
        }
        return first
    }

    static func getSchema(
        connection: SSCConnection,
        path: [String]
    ) async throws -> JSONData {
        let response = try await Self.queryAux(
            connection: connection,
            query: ["osc", "schema"],
            path: path
        )
        return path.reduce(response) { jd, p in jd[p]! }
    }

    static func getLimits(connection: SSCConnection, path: [String]) async throws
        -> OSCLimits?
    {
        let response = try await Self.queryAux(
            connection: connection,
            query: ["osc", "limits"],
            path: path
        )
        guard case .array(let vs) = response.unwrap() else {
            throw SSCNodeError.error("Malformed response")
        }
        guard case .object = vs.first else {
            throw SSCNodeError.error("Malformed array from schema request")
        }
        return OSCLimits(fromJSONObject: vs.first!)
    }

    private func populateLeaf(connection: SSCConnection) async throws {
        let path = pathToNode()
        limits = try await Self.getLimits(connection: connection, path: path)
        do {
            let data = try await connection.fetchSSCValueData(path: path)
            value = .value(try JSONDecoder().decode(JSONData.self, from: data).unwrap())
        } catch SSCConnection.DeviceError.notAcceptable {
            value = .error("Unfetchable node")
        }
    }

    private func populateInternal(connection: SSCConnection) async throws {
        // We are not at a leaf node and need to discover subcommands.
        let schema = try await Self.getSchema(
            connection: connection,
            path: pathToNode()
        )
        guard case .object(let dict) = schema else {
            throw SSCNodeError.error("osc/schema \(schema) is not an object.")
        }
        var subNodeArray: [SSCNode] = []
        for (k, v) in dict {
            let subNodeValue: NodeData
            if v == .null {
                subNodeValue = .unknownValue
            } else if v == .object([:]) {
                subNodeValue = .unknownChildren
            } else {
                throw SSCNodeError.malformedResponse(
                    String(describing: v) + " is neither null nor {}."
                )
            }
            subNodeArray.append(
                SSCNode(
                    name: k,
                    deviceID: self.id.deviceID,
                    parent: self,
                    value: subNodeValue
                )
            )
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
            if !recursive { return }
            for n in subNodeArray {
                try await n.populate(connection: connection, recursive: true)
            }
        case .unknownValue:
            try await populateLeaf(connection: connection)
        case .value, .error:
            return
        }
    }

    func populate(from schema: JSONSchema) {
        switch schema {
        case .null:
            value = .error("null")
        case .number(let l), .bool(let l), .string(let l), .array(_, let l):
            value = .value(JSONData(schema: schema))
            limits = l
        case .object(let dict):
            var children: [SSCNode] = []
            for k in dict.keys {
                let child = SSCNode(name: k, deviceID: self.id.deviceID, parent: self)
                child.populate(from: dict[k]!)
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
        case .value:
            value = .value(try await connection.fetchJSONData(path: pathToNode()))
        case .children, .unknown, .unknownChildren, .unknownValue:
            throw SSCNodeError.error("Node is not a populated leaf")
        }
    }

    // populates leaf nodes in subtree with data from the JSONData object. Assumes node
    // tree is already populated and that the node tree structure is a subtree of the
    // JSONData tree. Value-bearing Leaf nodes will assign data at path, no
    // questions asked.
    func load(from jsonData: JSONData) throws {
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
                    try child.load(from: subData)
                } else {
                    throw SSCNodeError.error("No value in data for \(child.name)")
                }
            })
        }
    }

    func load(from state: KHState) throws {
        // TODO
    }

    /// Returns list of child nodes, if there are any. This is for SSCTreeView lazy loading. Maybe we don't need this.
    var children: [SSCNode]? {
        if case .children(let c) = value {
            return c.sorted { a, b in
                if a.isLeaf() && !b.isLeaf() { return true }
                if !a.isLeaf() && b.isLeaf() { return false }
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
