//
//  JSONData.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.01.26.
//

import Foundation

enum JSONDataCodable: Equatable, Codable {
    case string(String, limits: OSCLimits? = nil)
    case number(Double, limits: OSCLimits? = nil)
    case bool(Bool, limits: OSCLimits? = nil)
    case array([JSONDataCodable], limits: OSCLimits? = nil)
    case null
    case object([String: JSONDataCodable])

    init(jsonData: JSONData, limits: OSCLimits? = nil) {
        switch jsonData {
        case .null:
            self = .null
        case .string(let string):
            self = .string(string, limits: limits)
        case .number(let number):
            self = .number(number, limits: limits)
        case .bool(let bool):
            self = .bool(bool, limits: limits)
        case .array(let array):
            self = .array(array.map({ .init(jsonData: $0) }), limits: limits)
        case .object(let object):
            self = .object(object.mapValues({ .init(jsonData: $0) }))
        }
    }

    @MainActor
    init?(fromNodeTree rootNode: SSCNode) {
        switch rootNode.value {
        case .value(let value):
            self.init(jsonData: value, limits: rootNode.limits)
        case .children(let children):
            var dict: [String: JSONDataCodable] = [:]
            children.forEach { child in
                dict[child.name] = JSONDataCodable(fromNodeTree: child)
            }
            self = .object(dict)
        default:
            self = .null
        }
    }

    subscript(index: String) -> JSONDataCodable? {
        if case .object(let dict) = self {
            return dict[index]
        }
        return nil
    }
}

enum JSONData: Equatable, Encodable, DecodableWithConfiguration {
    typealias DecodingConfiguration = JSONData

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
        case .string(let string, _):
            self = .string(string)
        case .number(let number, _):
            self = .number(number)
        case .bool(let bool, _):
            self = .bool(bool)
        case .array(let array, _):
            self = .array(array.map(JSONData.init))
        case .object(let object):
            self = .object(object.mapValues(JSONData.init))
        }
    }

    @MainActor
    init?(fromNodeTree rootNode: SSCNode) {
        guard let jdc = JSONDataCodable(fromNodeTree: rootNode) else {
            return nil
        }
        self.init(jsonDataCodable: jdc)
    }

    init(from decoder: Decoder, configuration: DecodingConfiguration) throws {
        struct MyStupidKey: CodingKey {
            var intValue: Int?
            var stringValue: String
            init?(intValue: Int) { return nil }
            init(stringValue: String) { self.stringValue = stringValue }
        }

        let currentPath = decoder.codingPath.map(\.stringValue)
        guard let currentValue = configuration.getAtPath(currentPath) else {
            throw JSONDataError.decodingError("Decoding path not found in schema")
        }

        switch currentValue {
        case .object(let children):
            let codingKeys = children.keys.map { MyStupidKey(stringValue: $0) }
            let container = try decoder.container(keyedBy: MyStupidKey.self)
            var dict = [String: JSONData]()
            for k in codingKeys {
                // dict[k.stringValue] = try .init(from: container.superDecoder(forKey: k))
                dict[k.stringValue] = try container.decode(
                    JSONData.self,
                    forKey: k,
                    configuration: configuration
                )
            }
            self = .object(dict)
        case .null:
            self = .null
        case .string:
            let svc = try decoder.singleValueContainer()
            guard let decoded = try? svc.decode(String.self) else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
            self = .string(decoded)
        case .number:
            let svc = try decoder.singleValueContainer()
            guard let decoded = try? svc.decode(Double.self) else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
            self = .number(decoded)
        case .bool:
            let svc = try decoder.singleValueContainer()
            guard let decoded = try? svc.decode(Bool.self) else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
            self = .bool(decoded)
        case .array(let vs):
            let svc = try decoder.singleValueContainer()
            switch vs.first {
            case .none:
                self = .array([])
            case .string:
                guard let decoded = try? svc.decode([String].self) else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
                self = .array(decoded.map(JSONData.string))
            case .number:
                guard let decoded = try? svc.decode([Double].self) else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
                self = .array(decoded.map(JSONData.number))
            case .bool:
                guard let decoded = try? svc.decode([Bool].self) else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
                self = .array(decoded.map(JSONData.bool))
            case .array, .object, .null:
                throw JSONDataError.decodingError(
                    "Nested arrays and null arrays not supported (yet)"
                )
            }
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

    private func asAny() -> Any? {
        switch self {
        case .null: nil
        case .number(let w): w
        case .string(let w): w
        case .bool(let w): w
        case .array(let w): w
        case .object(let w): w
        }
    }

    private func asArrayAny() -> [Any?]? {
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
        if case .object(let dict) = self {
            return dict[index]
        }
        return nil
    }
}
