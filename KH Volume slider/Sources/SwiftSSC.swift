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
    private var timeout: Task<Void, Never>?

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
    enum DeviceError: Int, CaseIterable, Error {
        case partialSuccess = 210
        case messageNotUnderstood = 400
        case notFound = 404
        case methodNotAllowed = 405
        case notAcceptable = 406
        case parameterAddressNotFound = 454
        case unknownError = -1
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

    deinit { connection.cancel() }

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

    private func open() async throws {
        switch connection.state {
        case .ready:
            // Connection is already established, just restart the timeout.
            timeoutStart()
            return
        case .preparing: break
        case .waiting:
            connection.restart()
        case .cancelled, .failed:
            connection = NWConnection(to: connection.endpoint, using: .tcp)
            fallthrough
        case .setup:
            connection.start(queue: dispatchQueue)
        @unknown default:
            throw ConnectionError.impossibleError
        }

        let deadline = Date.now.addingTimeInterval(5)
        while Date.now < deadline {
            if connection.state == .ready {
                // print("Connected to \(service?.0 ?? "unknown device")")
                timeoutStart()
                return
            }
        }
        throw ConnectionError.connectingTimedOut
    }

    private func close() {
        // print("Closing connection to \(service?.0 ?? "unknown device")")
        connection.cancel()
    }

    private func timeoutStart(seconds: Double = 5) {
        timeout?.cancel()
        timeout = Task {
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            close()
        }
    }

    private func sendDataFireAndForget(_ data: Data) async throws {
        try await open()
        return try await withCheckedThrowingContinuation { continuation in
            let sendCompHandler = NWConnection.SendCompletion.contentProcessed {
                error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
            connection.send(content: data, completion: sendCompHandler)
        }
    }

    private func receiveData() async throws -> Data {
        try await open()
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
                    continuation.resume(returning: data)
                    return
                }
                continuation.resume(throwing: ConnectionError.impossibleError)
            }
        }
    }

    private func sendData(_ content: Data) async throws -> Data {
        try await sendDataFireAndForget(content)
        let response = try await receiveData()
        // TODO more robust check with decoding this to JSONData or something
        guard let responseString = String(data: response, encoding: .utf8) else {
            throw ConnectionError.codingError
        }
        if responseString.starts(with: "{\"osc\":{\"error\"") {
            guard let contentString = String(data: content, encoding: .utf8) else {
                throw ConnectionError.codingError
            }
            // Special case: We asked for it.
            // .starts() because or \r\n.
            if contentString.starts(with: "{\"osc\":{\"error\":null}}") {
                return response
            }
            try DeviceError.allCases.forEach { err in
                if responseString.contains(String(err.rawValue)) { throw err }
            }
            print("Unknown error", responseString, "in response to", contentString)
            throw DeviceError.unknownError
        }
        return response
    }

    func sendSSCCommand(command: String) async throws -> String {
        guard let TXData = command.appending("\r\n").data(using: .ascii) else {
            throw ConnectionError.codingError
        }
        let RXData = try await sendData(TXData)
        guard let response = String(data: RXData, encoding: .utf8) else {
            throw ConnectionError.codingError
        }
        return response
    }

    func sendJSONData(_ jsonData: JSONData) async throws -> JSONData {
        let data = try JSONEncoder().encode(jsonData)
        try await sendDataFireAndForget(data)
        let RXData = try await receiveData()
        return try JSONDecoder().decode(JSONData.self, from: RXData)
    }

    static func pathToJSONString<T>(path: [String], value: T) throws -> String
    where T: Encodable {
        let jsonData = try JSONEncoder().encode(value)
        let jsonPath = String(data: jsonData, encoding: .utf8)!
        return path.reversed().reduce(jsonPath) { partial, p in
            "{\"\(p)\":\(partial)}"
        }
    }

    func sendSSCValue<T>(path: [String], value: T) async throws where T: Encodable {
        /// sends the command `{"p1":{"p2":value}}` to the device, if `path=["p1", "p2"]`.
        let jsonPath = try SSCConnection.pathToJSONString(path: path, value: value)
        try await _ = sendSSCCommand(command: jsonPath)
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

    func fetchSSCValueData(path: [String]) async throws -> Data {
        let jsonPath = try SSCConnection.pathToJSONString(
            path: path,
            value: nil as Float?
        )
        let RX = try await sendSSCCommand(command: jsonPath)
        return RX.data(using: .utf8)!
    }

    func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        let result = try await fetchSSCValueAny(path: path)
        guard let retval = result as? T else {
            throw ConnectionError.typeError
        }
        return retval
    }

    func fetchJSONData(path: [String], schema: JSONSchema) async throws -> JSONData {
        let data = try await fetchSSCValueData(path: path)
        return try JSONDecoder().decode(JSONData.self, from: data).unwrap()
    }
}
