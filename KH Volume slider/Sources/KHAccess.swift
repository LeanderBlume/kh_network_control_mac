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
    func getNodeByID(_ id: SSCNode.ID) -> SSCNode?

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
    func getNodeByID(_ id: SSCNode.ID) -> SSCNode?

    // specific
    var status: KHAccessStatus { get }
    
    // Truly specific
    var devices: [KHDevice] { get }
    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice?
    func scan(seconds: UInt32) async
}

enum KHAccessStatus: Equatable {
    case ready
    case busy(String)
    case error(String)

    func isBusy() -> Bool {
        switch self {
        case .busy:
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
    var status: KHAccessStatus = .error("Not initialized")

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
    }

    func getDeviceByID(_ id: KHDevice.ID) -> KHDevice? {
        return devices.first(where: { $0.id == id })
    }

    func getNodeByID(_ id: SSCNode.ID) -> SSCNode? {
        // devices.compactMap { $0.getNodeByID(id) }.first
        guard let owner = getDeviceByID(id.deviceID) else { return nil }
        return owner.getNodeByID(id)
    }

    func setup() async {
        if !devices.isEmpty {
            await setupDevices()
            return
        }
        let connectionCache = ConnectionCache()
        do {
            let connections = try connectionCache.getConnections()
            if connections.isEmpty {
                await scan()
            } else {
                devices = connections.map { KHDevice(connection: $0) }
            }
        } catch {
            print("error loading connections")
            await scan()
        }
        if devices.isEmpty {
            status = .error("No devices found")
            return
        }
        await setupDevices()
    }

    private func setupDevices() async {
        status = .busy("Setting up...")
        // We don't want to do this in parallel (naively) because of file system cache
        for d in devices {
            do {
                try await d.setup()
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
        // not sure
        // await fetchParameters()
        await fetch()
        state = devices[0].state
        status = .ready
    }

    func populateParameters() async {
        status = .busy("Querying...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.populateParameters() }
            }
            do {
                try await group.waitForAll()
                status = .ready
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
    }

    func fetchParameters() async {
        status = .busy("Fetching...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.fetchParameters() }
            }
            do {
                try await group.waitForAll()
                status = .ready
            } catch {
                status = .error(String(describing: error))
                return
            }
        }
    }

    func sendParameters() async {
        status = .busy("Sending...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.sendParameters() }
            }
            do {
                try await group.waitForAll()
                status = .ready
            } catch {
                status = .error(String(describing: error))
            }
        }
    }

    func fetch() async {
        if devices.isEmpty {
            status = .error("No devices")
            return
        }
        status = .busy("Fetching...")
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.fetch() }
            }
            do {
                try await group.waitForAll()
                state = devices.first!.state
                status = .ready
            } catch {
                status = .error(String(describing: error))
            }
        }
    }

    func send() async {
        await withThrowingTaskGroup { group in
            for i in devices.indices {
                group.addTask { try await self.devices[i].send(self.state) }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .error(String(describing: error))
            }
        }
    }

    func sendNode(deviceIndex i: Int, path: [String]) async {
        if !devices.indices.contains(i) {
            status = .error("Device \(i + 1) does not exist")
            return
        }
        do {
            try await devices[i].sendNode(path)
        } catch {
            status = .error(String(describing: error))
        }
    }

    func fetchNode(deviceIndex i: Int, path: [String]) async {
        if !devices.indices.contains(i) {
            status = .error("Device \(i + 1) does not exist")
            return
        }
        do {
            try await devices[i].fetchNode(path)
        } catch {
            status = .error(String(describing: error))
        }
    }
}
