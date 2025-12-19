//
//  SSCQuery.swift
//  KH Volume slider
//
//  Created by Leander Blume on 19.12.25.
//

import Foundation

enum JSONData {
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

class SSCNode {
    var device: SSCDevice
    var name: String
    var value: JSONData?
    var parent: SSCNode?
    var limits: OSCLimits?

    enum SSCNodeError: Error {
        case speakersNotReachable
        case badData
        case unknownTypeFromLimits(String?)
    }

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

    private func connect() async throws {
        if device.connection.state != .ready {
            device.connect()
        }
        let deadline = Date.now.addingTimeInterval(5)
        var success = false
        while Date.now < deadline {
            if device.connection.state == .ready {
                success = true
                break
            }
        }
        if !success {
            print("SSCNode connect timed out")
            throw SSCNodeError.speakersNotReachable
        }
    }

    private func disconnect() {
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

    // TODO lots of duplicate code between these functions. Factor out.
    func getSchema(path: [String]) async throws -> [String: [String: String]?] {
        var pathString = try SSCDevice.pathToJSONString(
            path: path,
            value: nil as String?
        )
        if !path.isEmpty {
            pathString = "[" + pathString + "]"
        }
        let queryCommand = #"{"osc":{"schema":"# + pathString + "}}"
        try await connect()
        let response: String = try device.sendSSCCommand(command: queryCommand).RX
        // disconnect()
        guard let data = response.data(using: .utf8) else {
            throw SSCNodeError.badData
        }
        let result =
            try! JSONSerialization.jsonObject(with: data, options: [])
            as! [String: [String: [[String: Any]]]]
        var result_ = result["osc"]!["schema"]![0]
        for p in path {
            result_ = result_[p] as! [String: Any]
        }
        return result_ as! [String: [String: String]?]
    }

    func getLimits(path: [String]) async throws -> OSCLimits {
        var pathString = try SSCDevice.pathToJSONString(
            path: path,
            value: nil as String?
        )
        if !path.isEmpty {
            pathString = "[" + pathString + "]"
        }
        let queryCommand = #"{"osc":{"limits":"# + pathString + "}}"
        try await connect()
        let response: String = try device.sendSSCCommand(command: queryCommand).RX
        // disconnect()
        guard let data = response.data(using: .utf8) else {
            throw SSCNodeError.badData
        }
        let result =
            try! JSONSerialization.jsonObject(with: data, options: [])
            as! [String: [String: [[String: Any?]]]]
        var result_ = result["osc"]!["limits"]![0]
        for p in path.dropLast() {
            result_ = result_[p] as! [String: Any?]
        }
        let result__ = result_[path.last!] as! [[String: Any?]]
        let result___ = result__[0]
        return OSCLimits(fromDict: result___)
    }

    func populateLeaf(path: [String]) async throws {
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

        // Count is given -> array type
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
        // This catch block doesn't catch anything. why
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

    func populate() async throws {
        let path = pathToNode()
        print(path)
        switch value {
        case nil:
            break
        case .null:
            try await populateLeaf(path: path)
            print(value)
            return
        case .error:
            // idk
            return
        default:  // An actual type
            print("already populated")
            // Or maybe an error?
            // Or maybe refetch?
            return
        }
        // We are not at a leaf node and need to discover subcommands.
        let resultStripped = try await getSchema(path: path)
        var subNodeArray: [SSCNode] = []
        for (k, v) in resultStripped {
            let subNodeValue: JSONData?
            if v == nil {
                subNodeValue = .null
            } else {
                subNodeValue = nil
            }
            subNodeArray.append(
                SSCNode(device: self.device, name: k, value: subNodeValue, parent: self)
            )
        }
        value = .object(subNodeArray)
        for n in subNodeArray {
            sleep(1)
            try await n.populate()
        }
        disconnect()
    }
}
