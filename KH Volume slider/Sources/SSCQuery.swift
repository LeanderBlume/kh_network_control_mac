//
//  SSCQuery.swift
//  KH Volume slider
//
//  Created by Leander Blume on 19.12.25.
//

import Foundation

enum JSONData: Equatable {
    case object([SSCNode])
    case string(String)
    case number(Double)
    case bool(Bool)
    case arrayString([String])
    case arrayNumber([Double])
    case arrayBool([Bool])
    case null
    case error(String)
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
    case speakersNotReachable
    case badData
    case unknownTypeFromLimits(String?)
    case unexpectedResponse(String)
    case caseDistinctionFailed
}

@Observable
class SSCNode: Identifiable, Equatable {
    var device: SSCDevice
    var name: String
    var value: JSONData?
    var parent: SSCNode?
    var limits: OSCLimits?
    // Maybe this is better than the default ObjectIdentifier. But I don't think so.
    // let id = UUID()

    init(
        device device_: SSCDevice,
        name name_: String,
        value value_: JSONData? = nil,
        parent parent_: SSCNode? = nil,
        limits limits_: OSCLimits? = nil,
    ) {
        device = device_
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
        var pathString = try SSCDevice.pathToJSONString(
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
        let response: String = try device.sendSSCCommand(command: queryCommand).RX
        guard let data = response.data(using: .utf8) else {
            throw SSCNodeError.badData
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

    private func populateLeaf(path: [String]) async throws {
        limits = try await getLimits(path: path)
        let response = try device.fetchSSCValueAny(path: path)
        // print(response)
        // In theory: Count is given => array type
        // But this is often wrong. There are various values with no count given at all
        // that are actually arrays. So we just try both single values and arrays.
        switch limits!.type {
        case "Number":
            if let v = response as? Double {
                value = .number(v)
            } else if let v = response as? [Double] {
                value = .arrayNumber(v)
            }
        case "String":
            if let v = response as? String {
                value = .string(v)
            } else if let v = response as? [String] {
                value = .arrayString(v)
            }
        case "Boolean":
            if let v = response as? Bool {
                value = .bool(v)
            } else if let v = response as? [Bool] {
                value = .arrayBool(v)
            }
        case .none:
            // Limits did not return a type, so We just try all types.
            // This does not work on its own. true/false and 0/1 can be converted into
            // each other so we will always get wrong results somewhere.
            // Can we use the "is" keyword?
            if let v = response as? Bool {
                value = .bool(v)
            } else if let v = response as? Double {
                value = .number(v)
            } else if let v = response as? String {
                value = .string(v)
            } else if let v = response as? [Bool] {
                value = .arrayBool(v)
            } else if let v = response as? [Double] {
                value = .arrayNumber(v)
            } else if let v = response as? [String] {
                value = .arrayString(v)
            } else {
                value = .error("Unknown type")
            }
        default:
            throw SSCNodeError.unknownTypeFromLimits(limits!.type)
        }
    }

    private func populateInternal(path: [String]) async throws {
        // We are not at a leaf node and need to discover subcommands.
        guard let resultStripped = try await getSchema(path: path) else {
            throw SSCNodeError.caseDistinctionFailed
        }
        var subNodeArray: [SSCNode] = []
        for (k, v) in resultStripped {
            let subNodeValue: JSONData?
            // TODO .null and nil are pretty confusing. Maybe use a different value?
            if v == nil {
                // There's a parameter!
                subNodeValue = .null
            } else if v == [:] {
                // There are subnodes to be discovered.
                subNodeValue = nil
            } else {
                throw SSCNodeError.unexpectedResponse(
                    String(describing: v) + " is neither null nor {}."
                )
            }
            subNodeArray.append(
                SSCNode(device: self.device, name: k, value: subNodeValue, parent: self)
            )
        }
        subNodeArray.sort { a, b in
            // We want to put non-objects first.
            if a.value == .null && b.value == nil {
                return true
            }
            if a.value == nil && b.value == .null {
                return false
            }
            return a.name < b.name
        }
        value = .object(subNodeArray)
    }

    func populate(recursive: Bool = true) async throws {
        // Populates the tree. Does not refresh previously fetched values!
        let path = pathToNode()
        // print("populating", path)
        switch value {
        case nil:
            try await populateInternal(path: path)
            if case .object(let subNodeArray) = value {
                for n in subNodeArray {
                    if recursive && (n.value == .null || n.value == nil) {
                        try await n.populate()
                    }
                }
            } else {
                throw SSCNodeError.caseDistinctionFailed
            }
        case .null:
            try await populateLeaf(path: path)
        default:  // An actual type
            break
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
        if case .object(let c) = value {
            return c
        }
        return nil
    }
    
    static func == (lhs: SSCNode, rhs: SSCNode) -> Bool {
        return (lhs.id == rhs.id)
    }
}
