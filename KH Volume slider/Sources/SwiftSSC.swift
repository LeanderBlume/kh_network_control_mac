//
//  SwiftSSC.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.03.25.
//
import Foundation
import Network

class SSCTransaction {
    var TX: String = ""
    var RX: String = ""
    var error: String = ""
}

class SSCDevice {
    var connection: NWConnection
    private let dispatchQueue: DispatchQueue

    enum SSCDeviceError: Error {
        case ipError
        case portError
        case noResponse
        case addressNotFound
        case messageNotUnderstood
        case wrongType
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

    static func scan(seconds: UInt32 = 1) -> [SSCDevice] {
        var retval: [SSCDevice] = []
        let q = DispatchQueue(label: "KH Discovery")
        let browser = NWBrowser(
            for: .bonjour(type: "_ssc._tcp", domain: nil),
            using: .tcp
        )
        browser.browseResultsChangedHandler = { (results, changes) in
            for result in results {
                retval.append(SSCDevice(endpoint: (result.endpoint)))
            }
        }
        browser.start(queue: q)
        sleep(seconds)
        return retval
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
            // print("timed out, could not connect")
            // status = .speakersUnavailable
            // throw KHAccessError.speakersNotReachable
        }
    }

    func disconnect() {
        connection.cancel()
    }

    func sendMessage(_ TXString: String) -> SSCTransaction {
        let transaction = SSCTransaction()
        let sendCompHandler = NWConnection.SendCompletion.contentProcessed {
            error in
            if let error = error {
                transaction.error = String(describing: error)
                return
            }
            transaction.TX = TXString
        }
        let TXraw = TXString.appending("\r\n").data(using: .ascii)!
        connection.send(content: TXraw, completion: sendCompHandler)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) {
            (content, context, isComplete, error) in
            guard let content = content else {
                transaction.error = String(describing: error)
                return
            }
            transaction.RX = String(data: content, encoding: .utf8) ?? "No Response"
        }
        return transaction
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

    func sendSSCCommand(command: String) throws -> SSCTransaction {
        let transaction = sendMessage(command)
        let deadline = Date.now.addingTimeInterval(5)
        var success = false
        while Date.now < deadline {
            if !transaction.RX.isEmpty {
                success = true
                break
            }
        }
        if !success {
            throw SSCDeviceError.noResponse
        }
        let RX = transaction.RX
        if RX.starts(with: "{\"osc\":{\"error\"") {
            if RX.contains("404") {
                throw SSCDeviceError.addressNotFound
            }
            if RX.contains("400") {
                throw SSCDeviceError.messageNotUnderstood
            }
        }
        return transaction
    }

    func sendSSCValue<T>(path: [String], value: T) throws where T: Encodable {
        /// sends the command `{"p1":{"p2":value}}` to the device, if `path=["p1", "p2"]`.
        let jsonPath = try SSCDevice.pathToJSONString(path: path, value: value)
        try _ = sendSSCCommand(command: jsonPath)
    }
    
    func fetchSSCValueAny(path: [String]) throws -> Any? {
        let jsonPath = try SSCDevice.pathToJSONString(path: path, value: nil as Float?)
        let transaction = try sendSSCCommand(command: jsonPath)
        let RX = transaction.RX
        let asObj = try JSONSerialization.jsonObject(with: RX.data(using: .utf8)!)
        let lastKey = path.last!
        var result: [String: Any] = asObj as! [String: Any]
        for p in path.dropLast() {
            result = result[p] as! [String: Any]
        }
        return result[lastKey]
    }

    func fetchSSCValue<T>(path: [String]) throws -> T where T: Decodable {
        let result = try fetchSSCValueAny(path: path)
        guard let retval = result as? T else {
            throw SSCDeviceError.wrongType
        }
        return retval
    }
}
