//
//  JSONData.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.01.26.
//

import Foundation

enum JSONDataCodable: Equatable, Sendable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONDataCodable])
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
            self = .array(array.map(JSONDataCodable.init))
        case .object(let object):
            self = .object(object.mapValues(JSONDataCodable.init))
        }
    }

    subscript(index: String) -> JSONDataCodable? {
        if case .object(let dict) = self {
            return dict[index]
        }
        return nil
    }
}

enum JSONDataSimple: Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case arrayString([String])
    case arrayNumber([Double])
    case arrayBool([Bool])

    init(state: KHState, keyPath: KeyPathType<KHState>) {
        switch keyPath {
        case .number(let keyPath):
            self = .number(state[keyPath: keyPath])
        case .bool(let keyPath):
            self = .bool(state[keyPath: keyPath])
        case .string(let keyPath):
            self = .string(state[keyPath: keyPath])
        case .arrayBool(let keyPath):
            self = .arrayBool(state[keyPath: keyPath])
        case .arrayNumber(let keyPath):
            self = .arrayNumber(state[keyPath: keyPath])
        case .arrayString(let keyPath):
            self = .arrayString(state[keyPath: keyPath])
        }
    }

    func set(
        into state: KHState,
        keyPath: KeyPathType<KHState>
    ) -> KHState {
        var newState = state
        switch self {
        case .number(let value):
            switch keyPath {
            case .number(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .string(let value):
            switch keyPath {
            case .string(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .bool(let value):
            switch keyPath {
            case .bool(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayNumber(let value):
            switch keyPath {
            case .arrayNumber(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayBool(let value):
            switch keyPath {
            case .arrayBool(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        case .arrayString(let value):
            switch keyPath {
            case .arrayString(let keyPath):
                newState[keyPath: keyPath] = value
            default:
                break
            }
        }
        return newState
    }
}

enum JSONData: Equatable, Sendable, Encodable, DecodableWithConfiguration {
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

    @MainActor
    init?(fromNodeTree rootNode: SSCNode) {
        switch rootNode.value {
        case .children(let children):
            var dict: [String: JSONData] = [:]
            children.forEach { child in
                dict[child.name] = .init(fromNodeTree: child)
            }
            self = .object(dict)
        case .value(let value):
            self = value
        default:
            self = .null
        }
    }

    init(from decoder: Decoder, configuration: DecodingConfiguration) throws {
        let currentPath = decoder.codingPath
        var currentValue: JSONData? = configuration
        for p in currentPath {
            currentValue = currentValue![p.stringValue]
            if currentValue == nil {
                throw JSONDataError.decodingError("Decoding path not found in schema")
            }
        }
        guard let currentValue else {
            throw JSONDataError.decodingError("Decoding path not found in schema")
        }

        struct MyStupidKey: CodingKey {
            var intValue: Int?
            var stringValue: String
            init?(intValue: Int) { return nil }
            init(stringValue: String) { self.stringValue = stringValue }
        }

        var codingKeys: [MyStupidKey] = []
        switch currentValue {
        case .object(let children):
            codingKeys = children.keys.map { MyStupidKey(stringValue: $0) }
            let values = try decoder.container(keyedBy: MyStupidKey.self)
            var dict = [String: JSONData]()
            for k in codingKeys {
                // dict[k.stringValue] = try .init(from: values.superDecoder(forKey: k))
                dict[k.stringValue] = try values.decode(
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
            if let decoded = try? svc.decode(String.self) {
                self = .string(decoded)
            } else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
        case .number:
            let svc = try decoder.singleValueContainer()
            if let decoded = try? svc.decode(Double.self) {
                self = .number(decoded)
            } else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
        case .bool:
            let svc = try decoder.singleValueContainer()
            if let decoded = try? svc.decode(Bool.self) {
                self = .bool(decoded)
            } else {
                throw JSONDataError.decodingError("Incorrect schema")
            }
        case .array(let vs):
            let svc = try decoder.singleValueContainer()
            switch vs.first {
            case .none:
                self = .array([])
            case .string:
                if let decoded = try? svc.decode([String].self) {
                    self = .array(decoded.map(JSONData.string))
                } else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
            case .number:
                if let decoded = try? svc.decode([Double].self) {
                    self = .array(decoded.map(JSONData.number))
                } else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
            case .bool:
                if let decoded = try? svc.decode([Bool].self) {
                    self = .array(decoded.map(JSONData.bool))
                } else {
                    throw JSONDataError.decodingError("Incorrect schema")
                }
            case .array, .object, .null:
                throw JSONDataError.decodingError(
                    "Nested arrays and null arrays not supported (yet)"
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .string(let v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case .number(let v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case .bool(let v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case .array(let v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        case .object(let v):
            var container = encoder.singleValueContainer()
            try container.encode(v)
        }
    }

    func wrap(in path: [String]) -> Self {
        var result = self
        for p in path.reversed() {
            result = .object([p: result])
        }
        return result
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

    func asArrayAny() -> [Any?]? {
        var result: [Any?] = []
        switch self {
        case .array(let vs):
            if vs.isEmpty {
                return []
            }
            for v in vs {
                switch v {
                case .number(let w):
                    result.append(w)
                case .string(let w):
                    result.append(w)
                case .bool(let w):
                    result.append(w)
                case .null:
                    result.append(nil)
                case .array:
                    result.append([])
                case .object:
                    result.append([:])
                }
            }
        default:
            return nil
        }
        return result
    }

    func asArrayNumber() -> [Double]? { return asArrayAny() as? [Double] }
    func asArrayString() -> [String]? { return asArrayAny() as? [String] }
    func asArrayBool() -> [Bool]? { return asArrayAny() as? [Bool] }

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

    subscript(index: String) -> JSONData? {
        if case .object(let dict) = self {
            return dict[index]
        }
        return nil
    }
}
