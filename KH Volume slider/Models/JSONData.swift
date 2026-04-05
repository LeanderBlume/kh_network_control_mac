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

enum JSONDataCodable: Equatable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONDataCodable])
    case null
    case object([String: JSONDataCodable])

    init(jsonData: JSONData) {
        switch jsonData {
        case .null:
            self = .null
        case .string(let string):
            self = .string(string)
        case .number(let number):
            self = .number(number)
        case .bool(let bool):
            self = .bool(bool)
        case .array(let array):
            self = .array(array.map({ .init(jsonData: $0) }))
        case .object(let object):
            self = .object(object.mapValues({ .init(jsonData: $0) }))
        }
    }

    @MainActor
    init?(rootNode: SSCNode) {
        switch rootNode.value {
        case .value(let value):
            self.init(jsonData: value)
        case .children(let children):
            var dict: [String: JSONDataCodable] = [:]
            children.forEach { child in
                dict[child.name] = JSONDataCodable(rootNode: child)
            }
            self = .object(dict)
        default:
            self = .null
        }
    }
}

enum JSONData: Equatable, Encodable {
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

    init(jsonDataCodable: JSONDataCodable) {
        switch jsonDataCodable {
        case .null:
            self = .null
        case .string(let string):
            self = .string(string)
        case .number(let number):
            self = .number(number)
        case .bool(let bool):
            self = .bool(bool)
        case .array(let array):
            self = .array(array.map(JSONData.init))
        case .object(let object):
            self = .object(object.mapValues(JSONData.init))
        }
    }

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

    init(decodeFrom data: Data) throws {
        let v = try JSONSerialization.jsonObject(
            with: data,
            options: [.fragmentsAllowed]
        )
        try self.init(fromAny: v)
    }

    init(fromAny v: Any) throws {
        if let vDict = v as? [String: Any] {
            var objectDict = [String: JSONData]()
            for (k, v) in vDict {
                objectDict[k] = try JSONData(fromAny: v)
            }
            self = .object(objectDict)
        } else if let vArray = v as? [Any] {
            let jsonArray: [JSONData] = try vArray.map { try JSONData(fromAny: $0) }
            self = .array(jsonArray)
        } else if let vString = v as? String {
            self = .string(vString)
        } else if let vNumber = v as? NSNumber {
            if vNumber === kCFBooleanTrue || vNumber === kCFBooleanFalse {
                self = .bool(vNumber.boolValue)
            } else {
                self = .number(vNumber.doubleValue)
            }
        } else if v as? NSNull != nil {
            self = .null
        } else {
            throw JSONDataError.decodingError(
                "Converting of \(v) from Any fell through."
            )
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
        case .array(let w): w
        case .object(let w): w
        }
    }

    func asArrayAny() -> [Any?]? {
        if case .array(let vs) = self {
            return vs.map({ $0.asAny() })
        }
        return nil
    }

    func asArrayNumber() -> [Double]? { asArrayAny() as? [Double] }
    func asArrayString() -> [String]? { asArrayAny() as? [String] }
    func asArrayBool() -> [Bool]? { asArrayAny() as? [Bool] }

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
            var result: [String: String] = [:]
            for (k, v) in vs {
                result[k] = v.stringify()
            }
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
