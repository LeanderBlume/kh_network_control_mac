//
//  JSONData.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.01.26.
//

enum JSONData: Equatable, Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONData])
    case object([String: JSONData])
    
    enum JSONDataError: Error {
        case error(String)
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

    func fetch(connection: SSCConnection, path: [String]) async throws -> JSONData {
        switch self {
        case .null:
            return self
        case .number:
            return .number(try await connection.fetchSSCValue(path: path))
        case .string:
            return .string(try await connection.fetchSSCValue(path: path))
        case .bool:
            return .bool(try await connection.fetchSSCValue(path: path))
        case .array(let vs):
            switch vs.first {
            case .null:
                return self
            case .number:
                let newV: [Double] = try await connection.fetchSSCValue(path: path)
                return .array(newV.map({ JSONData.number($0) }))
            case .string:
                let newV: [String] = try await connection.fetchSSCValue(path: path)
                return .array(newV.map({ JSONData.string($0) }))
            case .bool:
                let newV: [Bool] = try await connection.fetchSSCValue(path: path)
                return .array(newV.map({ JSONData.bool($0) }))
            case nil:
                throw JSONDataError.error("Could not determine type of empty array")
            case .array, .object:
                throw JSONDataError.error("Nested container types are not supported")
            }
        case .object:
            throw JSONDataError.error("Path does not lead to a value")
        }
    }
}
