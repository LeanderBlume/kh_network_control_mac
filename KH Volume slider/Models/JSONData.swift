//
//  JSONData.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.01.26.
//

import Foundation

enum JSONSchema: Codable {
    case string(limits: OSCLimits? = nil)
    case number(limits: OSCLimits? = nil)
    case bool(limits: OSCLimits? = nil)
    indirect case array(type: JSONSchema?, limits: OSCLimits? = nil)
    case null
    case object([String: JSONSchema])

    init(jsonData: JSONData, limits: OSCLimits? = nil) {
        switch jsonData {
        case .null:
            self = .null
        case .string:
            self = .string(limits: limits)
        case .number:
            self = .number(limits: limits)
        case .bool:
            self = .bool(limits: limits)
        case .array(let vs):
            var type: JSONSchema? = nil
            if let v = vs.first {
                type = JSONSchema.init(jsonData: v)
            }
            self = .array(type: type, limits: limits)
        case .object(let object):
            self = .object(object.mapValues({ .init(jsonData: $0) }))
        }
    }

    @MainActor
    init?(rootNode: SSCNode) {
        switch rootNode.value {
        case .value(let value):
            self.init(jsonData: value, limits: rootNode.limits)
        case .children(let children):
            var dict = [String: Self]()
            children.forEach { child in
                dict[child.name] = .init(rootNode: child)
            }
            self = .object(dict)
        default:
            self = .null
        }
    }

    subscript(index: String) -> Self? {
        guard case .object(let dict) = self else { return nil }
        return dict[index]
    }

    func getAtPath(_ path: [String]) -> Self? {
        var curr = self
        for p in path {
            guard let child = curr[p] else { return nil }
            curr = child
        }
        return curr
    }

    func wrap(in path: [String]) -> Self {
        return path.reversed().reduce(self) { (partial, key) in
            .object([key: partial])
        }
    }

    // removes layers of single key objects until something else remains.
    func unwrap() -> Self {
        if case .object(let v) = self {
            if v.count == 1 {
                return v.values.first!.unwrap()
            }
        }
        return self
    }
}

enum JSONData: Equatable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONData])
    case object([String: JSONData])

    enum JSONDataError: Error {
        case error(String)
        case decodingError(String)
    }

    init(singleValue: String) { self = .string(singleValue) }
    init(singleValue: Double) { self = .number(singleValue) }
    init(singleValue: Bool) { self = .bool(singleValue) }
    init(singleValue: [String]) { self = .array(singleValue.map({ .string($0) })) }
    init(singleValue: [Double]) { self = .array(singleValue.map({ .number($0) })) }
    init(singleValue: [Bool]) { self = .array(singleValue.map({ .bool($0) })) }

    init(schema: JSONSchema) {
        switch schema {
        case .null:
            self = .null
        case .string:
            self = .string("")
        case .number:
            self = .number(0)
        case .bool:
            self = .bool(false)
        case .array(let type, _):
            if let type {
                self = .array([JSONData(schema: type)])
            } else {
                self = .array([])
            }
        case .object(let object):
            self = .object(object.mapValues(JSONData.init))
        }
    }

    @MainActor
    init?(rootNode: SSCNode) {
        switch rootNode.value {
        case .value(let value):
            self = value
        case .children(let children):
            var dict: [String: Self] = [:]
            children.forEach { child in
                dict[child.name] = .init(rootNode: child)
            }
            self = .object(dict)
        default:
            self = .null
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let vDict = try? container.decode([String: JSONData].self) {
            self = .object(vDict)
        } else if let vArray = try? container.decode([JSONData].self) {
            self = .array(vArray)
        } else if let vString = try? container.decode(String.self) {
            self = .string(vString)
        } else if let vBool = try? container.decode(Bool.self) {
            self = .bool(vBool)
        } else if let vNumber = try? container.decode(Double.self) {
            self = .number(vNumber)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .string(let v):
            try container.encode(v)
        case .number(let v):
            try container.encode(v)
        case .bool(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .object(let v):
            try container.encode(v)
        }
    }

    func asAny() -> Any? {
        switch self {
        case .null: nil
        case .number(let w): w
        case .string(let w): w
        case .bool(let w): w
        case .object(let w): w.mapValues { $0.asAny() }
        case .array(let w): w.map { $0.asAny() }
        }
    }

    func asType<T>() -> T? { asAny() as? T }

    func stringify() -> String {
        switch self {
        case .string(let v):
            return "\"" + v + "\""
        case .number(let v):
            return String(v)
        case .bool(let v):
            return String(v)
        case .null:
            return "null"
        case .array(let vs):
            return "[" + vs.map({ $0.stringify() }).joined(separator: ", ") + "]"
        case .object(let vs):
            let result = vs.mapValues { $0.stringify() }
            return String(describing: result)
        }
    }

    func wrap(in path: [String]) -> Self {
        return path.reversed().reduce(self) { (partial, key) in
            .object([key: partial])
        }
    }

    // removes layers of single key objects until something else remains.
    func unwrap() -> Self {
        if case .object(let v) = self {
            if v.count == 1 {
                return v.values.first!.unwrap()
            }
        }
        return self
    }

    func getAtPath(_ path: [String]) -> JSONData? {
        var curr = self
        for p in path {
            guard let child = curr[p] else { return nil }
            curr = child
        }
        return curr
    }

    subscript(index: String) -> JSONData? {
        get {
            guard case .object(let dict) = self else { return nil }
            return dict[index]
        }
        set(value) {
            guard case .object(let dict) = self else {
                print("Can't set value in non-object via subscript")
                return
            }
            var newDict = dict
            newDict[index] = value
            self = .object(newDict)
        }
    }
}
