//
//  KHAccessNative.swift
//  KH Volume slider
//
//  Created by Leander Blume on 31.03.25.
//

import SwiftUI

typealias KHAccess = KHAccessNative

@MainActor
protocol KHCommonProtocol {
    var state: KHState { get }
    var status: KHAccessStatus { get }
    func setup() async
    func fetch() async
    func populateParameters() async
    func sendParameterTree() async
    func fetchParameterTree() async
    func getNodeByID(_: SSCNode.ID) -> SSCNode?
}

@MainActor
protocol KHDeviceProtocol: KHCommonProtocol, Identifiable {
    func send(_: KHState) async

    // specific
    init(connection: SSCConnection)
    func sendNode(path: [String]) async
    func fetchNode(path: [String]) async
}

@MainActor
protocol KHAccessProtocol: KHCommonProtocol {
    func send() async

    // Truly specific
    var devices: [KHDevice] { get }
    func getDeviceByID(_: KHDevice.ID) -> KHDevice?
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

    static func aggregate(_ stati: [KHAccessStatus]) -> KHAccessStatus {
        guard !stati.isEmpty else {
            return .error("No devices")
        }
        return stati.reduce(.ready) { partial, next in
            switch (partial, next) {
            case (.ready, .ready):
                return .ready
            case (.busy(let msg1), .busy(let msg2)):
                if msg1 == msg2 {
                    return .busy(msg1)
                }
                return .busy("\(msg1), \(msg2)")
            case (.error(let msg1), .error(let msg2)):
                if msg1 == msg2 {
                    return .error(msg1)
                }
                return .error("\(msg1), \(msg2)")
            case (.ready, .busy(let msg)), (.busy(let msg), .ready):
                return .busy(msg)
            case (.ready, .error(let msg)), (.error(let msg), .ready):
                return .error(msg)
            case (.error(let E), .busy), (.busy, .error(let E)):
                return .busy(E)
            }
        }
    }
}

enum KHAccessError: Error {
    case speakersNotReachable
    case noSpeakersFoundDuringScan
}

@Observable
final class KHAccessNative: KHAccessProtocol {
    var state = KHState()
    private var statusOverride: KHAccessStatus? = nil
    var status: KHAccessStatus {
        statusOverride ?? KHAccessStatus.aggregate(devices.map(\.status))
    }

    var devices: [KHDevice] = []

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        statusOverride = .busy("Scanning...")
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
        statusOverride = nil
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
            print("error loading connections: \(error)")
            await scan()
        }
        guard !devices.isEmpty else { return }
        await setupDevices()
    }

    private func setupDevices() async {
        // We don't want to do this in parallel (naively) because of file system cache
        for d in devices {
            await d.setup()
        }
        // not sure
        // await fetchParameters()
        await fetch()
        state = devices[0].state
    }

    func populateParameters() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.populateParameters() }
            }
            await group.waitForAll()
        }
    }

    func fetchParameterTree() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetchParameterTree() }
            }
            await group.waitForAll()
        }
    }

    func sendParameterTree() async {
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.sendParameterTree() }
            }
            await group.waitForAll()
        }
    }

    func fetch() async {
        guard !devices.isEmpty else { return }
        await withTaskGroup { group in
            for d in devices {
                group.addTask { await d.fetch() }
            }
            await group.waitForAll()
            state = devices.first!.state
        }
    }

    func send() async {
        await withTaskGroup { group in
            for i in devices.indices {
                group.addTask { await self.devices[i].send(self.state) }
            }
            await group.waitForAll()
        }
    }
}
