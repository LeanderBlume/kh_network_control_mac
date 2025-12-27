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
class SSCNode: Identifiable, Equatable, Hashable {
    var device: SSCDevice
    var name: String
    var value: JSONData?
    var parent: SSCNode?
    var limits: OSCLimits?

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

    func connect() async throws {
        try await device.connect()
    }

    func disconnect() {
        device.disconnect()
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
        // Special cases that we just need to handle manually because the type given by
        // limits is wrong.
        switch path {
        case ["m", "in", "level"], ["m", "in", "clip"]:
            value = .arrayNumber(try device.fetchSSCValue(path: path))
            return
        case ["audio", "out", "mixer", "inputs"]:
            value = .arrayString(try device.fetchSSCValue(path: path))
            return
        default:
            break
        }

        // Now do limits to discover the type
        limits = try await getLimits(path: path)

        // Count is given => array type
        if let count = limits!.count {
            if count > 1 {
                switch limits!.type {
                case "Number":
                    value = .arrayNumber(try device.fetchSSCValue(path: path))
                case "String":
                    value = .arrayString(try device.fetchSSCValue(path: path))
                case "Boolean":
                    value = .arrayBool(try device.fetchSSCValue(path: path))
                default:
                    throw SSCNodeError.unknownTypeFromLimits(limits!.type)
                }
                return
            }
        }

        // standard case, single values
        do {
            switch limits!.type {
            case "Number":
                value = .number(try device.fetchSSCValue(path: path))
            case "String":
                value = .string(try device.fetchSSCValue(path: path))
            case "Boolean":
                value = .bool(try device.fetchSSCValue(path: path))
            case nil:
                value = .error("No type given by limits")
            default:
                throw SSCNodeError.unknownTypeFromLimits(limits!.type)
            }
        } catch SSCDevice.SSCDeviceError.wrongType {
            value = .error("Wrong type given by limits")
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
        print("populating", path)
        switch value {
        case nil:
            try await populateInternal(path: path)
            if case .object(let subNodeArray) = value {
                for n in subNodeArray {
                    if recursive && (n.value == .null || n.value == nil) {
                        // WOW with the better connection handling (WIP), we don't even
                        // need a delay here anymore.
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
        return lhs.pathToNode() == rhs.pathToNode()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pathToNode())
    }
}
