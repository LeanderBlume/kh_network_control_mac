//
//  SwiftSSC.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.03.25.
//
import Foundation
import Network

actor SSCConnection {
    private var connection: NWConnection
    private let dispatchQueue: DispatchQueue

    var service: (String, String, String)? {
        switch self.connection.endpoint {
        case .service(name: let n, type: let t, domain: let d, interface: _):
            return (n, t, d)
        default:
            return nil
        }
    }

    // Something goes wrong with the connection itself
    enum ConnectionError: Error {
        case connectingTimedOut
        case emptyResponse
        case typeError
        case codingError
        case impossibleError
    }

    // Connection succeeds, but device returns an error
    enum DeviceError: Error {
        case addressNotFound(String)
        case messageNotUnderstood(String)
    }

    init?(ip: String, port: Int = 45) {
        guard let addr = IPv6Address(ip) else {
            return nil
        }
        let hostEndpoint = NWEndpoint.Host.ipv6(addr)
        guard let portEndpoint = NWEndpoint.Port(String(port)) else {
            return nil
        }
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        connection = NWConnection(to: endpoint, using: .tcp)
        dispatchQueue = DispatchQueue(label: "KH Speaker connection")
    }

    init(serviceName: String, type: String, domain: String) {
        let endpoint = NWEndpoint.service(
            name: serviceName,
            type: type,
            domain: domain,
            interface: nil
        )
        self.init(endpoint: endpoint)
    }

    init(endpoint: NWEndpoint) {
        connection = NWConnection(to: endpoint, using: .tcp)
        dispatchQueue = DispatchQueue(label: "KH Speaker connection")
    }

    static func scan(seconds: UInt32 = 1) async -> [SSCConnection] {
        let q = DispatchQueue(label: "KH Discovery")
        let browser = NWBrowser(
            for: .bonjour(type: "_ssc._tcp", domain: nil),
            using: .tcp
        )
        browser.start(queue: q)
        sleep(seconds)
        return browser.browseResults.map { SSCConnection(endpoint: $0.endpoint) }
    }

    func open() async throws {
        switch connection.state {
        case .ready: return
        case .preparing: break
        case .waiting:
            connection.restart()
        case .cancelled, .failed:
            connection = NWConnection(to: connection.endpoint, using: .tcp)
            fallthrough
        default:
            connection.start(queue: dispatchQueue)
        }
        let deadline = Date.now.addingTimeInterval(5)
        while Date.now < deadline {
            if connection.state == .ready { return }
        }
        throw ConnectionError.connectingTimedOut
    }

    func close() { connection.cancel() }

    static func pathToJSONString<T>(path: [String], value: T) throws -> String
    where T: Encodable {
        let jsonData = try JSONEncoder().encode(value)
        let jsonPath = String(data: jsonData, encoding: .utf8)!
        return path.reversed().reduce(jsonPath) { partial, p in
            "{\"\(p)\":\(partial)}"
        }
    }

    private func sendMessage(_ TXString: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let sendCompHandler = NWConnection.SendCompletion.contentProcessed {
                error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
            }
            let TXraw = TXString.appending("\r\n").data(using: .ascii)!
            connection.send(content: TXraw, completion: sendCompHandler)
            continuation.resume(returning: ())
        }
    }

    private func receiveMessage() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 512) {
                (data, context, isComplete, error) in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if isComplete && data == nil {
                    continuation.resume(throwing: ConnectionError.emptyResponse)
                    return
                }
                if let data {
                    guard let response = String(data: data, encoding: .utf8) else {
                        continuation.resume(throwing: ConnectionError.codingError)
                        return
                    }
                    continuation.resume(returning: response)
                    return
                }
                continuation.resume(throwing: ConnectionError.impossibleError)
            }
        }
    }

    func sendSSCCommand(command: String) async throws -> String {
        try await sendMessage(command)
        let RX = try await receiveMessage()
        if RX.starts(with: "{\"osc\":{\"error\"") {
            if RX.contains("404") { throw DeviceError.addressNotFound(command) }
            if RX.contains("400") { throw DeviceError.messageNotUnderstood(command) }
        }
        return RX
    }

    func sendSSCValue<T>(path: [String], value: T) async throws where T: Encodable {
        /// sends the command `{"p1":{"p2":value}}` to the device, if `path=["p1", "p2"]`.
        let jsonPath = try SSCConnection.pathToJSONString(path: path, value: value)
        try await _ = sendSSCCommand(command: jsonPath)
    }

    func fetchSSCValueData(path: [String]) async throws -> Data {
        let jsonPath = try SSCConnection.pathToJSONString(
            path: path,
            value: nil as Float?
        )
        let RX = try await sendSSCCommand(command: jsonPath)
        return RX.data(using: .utf8)!
    }

    private func fetchSSCValueAny(path: [String]) async throws -> Any? {
        let jsonPath = try SSCConnection.pathToJSONString(
            path: path,
            value: nil as Float?
        )
        let RX = try await sendSSCCommand(command: jsonPath)
        let asObj = try JSONSerialization.jsonObject(with: RX.data(using: .utf8)!)
        let lastKey = path.last!
        var result = asObj as! [String: Any]
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        return result[lastKey]
    }

    func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        let result = try await fetchSSCValueAny(path: path)
        guard let retval = result as? T else {
            throw ConnectionError.typeError
        }
        return retval
    }

    func fetchJSONData(path: [String], type: JSONData) async throws -> JSONData {
        let data = try await fetchSSCValueData(path: path)
        let decoder = JSONDecoder()
        return try decoder.decode(
            JSONData.self,
            from: data,
            configuration: type.wrap(in: path)
        ).unwrap()
    }
}
