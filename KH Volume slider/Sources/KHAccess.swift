//
//  KHAccessNative.swift
//  KH Volume slider
//
//  Created by Leander Blume on 31.03.25.
//

import SwiftUI

typealias KHAccess = KHAccessNative

@MainActor
protocol KHDeviceProtocol: Identifiable {
    // more or less common
    var state: KHState { get }
    func setup() async throws
    func send(_ newState: KHState) async throws
    func fetch() async throws
    func populateParameters() async throws
    func sendNode(_: [String]) async throws
    func fetchNode(_: [String]) async throws
    func sendParameters() async throws
    func fetchParameters() async throws

    // specific
    init(connection connection_: SSCConnection)
    var connection: SSCConnection { get }
}

@MainActor
protocol KHAccessProtocol {
    // more or less common
    var state: KHState { get }
    func setup() async
    func send() async
    func fetch() async
    func populateParameters() async
    func sendNode(deviceIndex: Int, path: [String]) async
    func fetchNode(deviceIndex: Int, path: [String]) async
    func sendParameters() async
    func fetchParameters() async

    // specific
    var status: KHAccessStatus { get }
    var devices: [KHDevice] { get }
    func scan(seconds: UInt32) async
    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice?
    func getNodeByID(_ id: SSCNode.ID) -> SSCNode?
}

enum KHAccessStatus: Equatable {
    case clean
    case success
    case speakersFound(Int)
    case busy(String?)
    case queryingParameters
    case couldNotConnect
    case otherError(String)

    func isClean() -> Bool {
        switch self {
        case .clean, .success:
            return true
        case .speakersFound(let n):
            return n > 0
        default:
            return false
        }
    }

    func isBusy() -> Bool {
        switch self {
        case .busy, .queryingParameters:
            return true
        default:
            return false
        }
    }
}

enum KHAccessError: Error {
    case speakersNotReachable
    case noSpeakersFoundDuringScan
}

@Observable
final class KHAccessNative: KHAccessProtocol {
    /*
     Fetches, sends and stores data from speakers.
     */
    var state = KHState()
    var devices: [KHDevice] = []
    var status: KHAccessStatus = .speakersFound(0)

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        status = .busy("Scanning...")
        let connectionCache = ConnectionCache()
        do {
            try await connectionCache.clearConnections()
        } catch {
            print(error)
        }
        let connections = await SSCConnection.scan(seconds: seconds)
        do {
            try await connectionCache.saveConnections(connections)
        } catch {
            print(error)
        }
        devices = connections.map { KHDevice(connection: $0) }
        status = .speakersFound(devices.count)
    }

    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice? {
        return devices.first(where: { $0.id == id })
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? {
        guard let owner = getDeviceByID(id.deviceID) else { return nil }
        print("FOUND OWNER")
        guard let rootNode = owner.parameterTree else { return nil }
        print("POPULATED")
        return rootNode.first(where: { $0.id == id })
    }

    func setup() async {
        if devices.isEmpty {
            let connectionCache = ConnectionCache()
            if let connections = try? connectionCache.getConnections() {
                if connections.isEmpty {
                    await scan()
                } else {
                    devices = connections.map { KHDevice(connection: $0) }
                    status = .speakersFound(devices.count)
                }
            } else {
                print("error loading connections")
                await scan()
            }
            if status == .speakersFound(0) {
                return
            }
        }
        await setupDevices()
    }

    private func setupDevices() async {
        status = .busy("Setting up...")
        for d in devices {
            do { try await d.setup() } catch {
                print(error)
                status = .otherError(String(describing: error))
                return
            }
        }
        // not sure
        // await fetchParameters()
        await fetch()
        state = devices[0].state
        status = .success
    }

    func populateParameters() async {
        status = .queryingParameters
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.populateParameters() }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
                return
            }
        }
        status = .success
    }

    func fetchParameters() async {
        status = .busy("Fetching...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.fetchParameters() }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
                return
            }
        }
        status = .success
    }

    func sendParameters() async {
        status = .busy("Sending...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.sendParameters() }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
                return
            }
        }
        status = .success
    }

    func fetch() async {
        status = .busy("Fetching...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.fetch() }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
            }
        }
        state = devices.first!.state
        status = .success
    }

    func send() async {
        await withThrowingTaskGroup { group in
            for i in devices.indices {
                group.addTask { try await self.devices[i].send(self.state) }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
            }
        }
    }

    func sendNode(deviceIndex i: Int, path: [String]) async {
        if !devices.indices.contains(i) {
            status = .otherError("Device does not exist")
        }
        do {
            try await devices[i].sendNode(path)
        } catch {
            status = .otherError(String(describing: error))
        }
    }

    func fetchNode(deviceIndex i: Int, path: [String]) async {
        if !devices.indices.contains(i) {
            status = .otherError("Device does not exist")
        }
        do {
            try await devices[i].fetchNode(path)
        } catch {
            status = .otherError(String(describing: error))
        }
    }
}
