//
//  SwiftSSC.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.03.25.
//
import Foundation
import Network

class SSCDevice {
    var connection: NWConnection
    private let dispatchQueue: DispatchQueue
    var status: String = ""

    enum SSCDeviceError: Error {
        case ipError
        case portError
        case noResponse
        case addressNotFound
        case messageNotUnderstood
        case wrongType
        case sendError(String)
        case error(String)
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

    init(endpoint: NWEndpoint) {
        connection = NWConnection(to: endpoint, using: .tcp)
        dispatchQueue = DispatchQueue(label: "KH Speaker connection")
    }

    static func scan(seconds: UInt32 = 1) async -> [SSCDevice] {
        let q = DispatchQueue(label: "KH Discovery")
        let browser = NWBrowser(
            for: .bonjour(type: "_ssc._tcp", domain: nil),
            using: .tcp
        )
        browser.start(queue: q)
        sleep(seconds)
        return browser.browseResults.map { SSCDevice(endpoint: $0.endpoint) }
    }

    func connect() async throws {
        switch connection.state {
        case .ready, .preparing:
            return
        case .waiting:
            connection.restart()
        case .cancelled, .failed:
            connection = NWConnection(to: connection.endpoint, using: .tcp)
            connection.start(queue: dispatchQueue)
        default:
            connection.start(queue: dispatchQueue)
        }
        let deadline = Date.now.addingTimeInterval(5)
        var success = false
        while Date.now < deadline {
            if connection.state == .ready {
                success = true
                break
            }
        }
        if !success {
            throw SSCDeviceError.noResponse
        }
    }

    func disconnect() {
        connection.cancel()
    }

    private func sendMessage(_ TXString: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let sendCompHandler = NWConnection.SendCompletion.contentProcessed {
                error in
                if error != nil {
                    continuation.resume(
                        throwing: SSCDeviceError.sendError(String(describing: error))
                    )
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
                if data == nil {
                    continuation.resume(throwing: SSCDeviceError.noResponse)
                    return
                }
                let response = String(data: data!, encoding: .utf8) ?? ""
                continuation.resume(returning: response)
            }
        }
    }

    static func pathToJSONString<T>(path: [String], value: T) throws -> String
    where T: Encodable {
        let jsonData = try JSONEncoder().encode(value)
        var jsonPath = String(data: jsonData, encoding: .utf8)!
        for p in path.reversed() {
            jsonPath = "{\"\(p)\":\(jsonPath)}"
        }
        return jsonPath
    }

    func sendSSCCommand(command: String) async throws -> String {
        try await sendMessage(command)
        let RX = try await receiveMessage()
        let deadline = Date.now.addingTimeInterval(5)
        var success = false
        while Date.now < deadline {
            if !RX.isEmpty {
                success = true
                break
            }
        }
        if !success {
            throw SSCDeviceError.noResponse
        }
        if RX.starts(with: "{\"osc\":{\"error\"") {
            if RX.contains("404") {
                throw SSCDeviceError.addressNotFound
            }
            if RX.contains("400") {
                throw SSCDeviceError.messageNotUnderstood
            }
        }
        return RX
    }

    func sendSSCValue<T>(path: [String], value: T) async throws where T: Encodable {
        /// sends the command `{"p1":{"p2":value}}` to the device, if `path=["p1", "p2"]`.
        let jsonPath = try SSCDevice.pathToJSONString(path: path, value: value)
        try await _ = sendSSCCommand(command: jsonPath)
    }

    func fetchSSCValueAny(path: [String]) async throws -> Any? {
        let jsonPath = try SSCDevice.pathToJSONString(path: path, value: nil as Float?)
        let RX = try await sendSSCCommand(command: jsonPath)
        let asObj = try JSONSerialization.jsonObject(with: RX.data(using: .utf8)!)
        let lastKey = path.last!
        var result: [String: Any] = asObj as! [String: Any]
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        return result[lastKey]
    }

    func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        let result = try await fetchSSCValueAny(path: path)
        guard let retval = result as? T else {
            throw SSCDeviceError.wrongType
        }
        return retval
    }
}
