//
//  KHAccessNative.swift
//  KH Volume slider
//
//  Created by Leander Blume on 31.03.25.
//

import SwiftUI

typealias KHAccess = KHAccessNative

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

@MainActor
protocol KHAccessProtocol: Observable, Identifiable {
    var state: KHState { get }
    var devices: [KHDevice] { get }
    var status: KHAccessStatus { get }

    func scan(seconds: UInt32) async
    func setup() async
    func populateParameters() async
    func send() async
    func fetch() async
    func sendNode(deviceIndex: Int, path: [String]) async
    func fetchNode(deviceIndex: Int, path: [String]) async
}

@Observable
final class KHAccessNative: KHAccessProtocol {
    /*
     Fetches, sends and stores data from speakers.
     */
    // UI state
    var state = KHState()
    var devices: [KHDevice] = []
    var status: KHAccessStatus = .speakersFound(0)

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        status = .busy("Scanning...")
        let connections = await SSCConnection.scan(seconds: seconds)
        devices = connections.map { KHDevice(connection: $0) }
        status = .speakersFound(devices.count)
    }

    func setup() async {
        if devices.isEmpty {
            await scan()
            if status == .speakersFound(0) {
                return
            }
        }
        await setupDevices()
    }

    private func setupDevices() async {
        status = .busy("Setting up...")
        /*
        await withThrowingTaskGroup { group in
            for d in devices {
                group.addTask { try await d.setup() }
            }
            do {
                try await group.waitForAll()
            } catch {
                status = .otherError(String(describing: error))
            }
        }
         */
        for d in devices {
            do { try await d.setup() } catch {
                print(error)
                status = .otherError(String(describing: error))
                return
            }
        }
        // not sure
        // await fetchParameters()
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

@Observable
final class KHAccessDummy: KHAccessProtocol {
    /*
     Fetches, sends and stores data from speakers.
     */
    /// I was wondering whether we should just store a KHJSON instance instead of these values because the whole
    /// thing seems a bit doubled up. But maybe this is good as an abstraction layer between the json and the GUI.

    // UI state
    var state = KHState()
    var devices: [KHDevice] = []
    var status: KHAccessStatus = .clean

    private func sleepOneSecond() async {
        do {
            try await Task.sleep(nanoseconds: 1000_000_000)
        } catch {
            status = .otherError("Sleeping failed")
        }
    }

    func scan(seconds: UInt32 = 1) async {
        status = .busy("Scanning...")
        await sleepOneSecond()
        status = .speakersFound(2)
    }

    func setup() async {
        status = .busy("Setting up...")
        await sleepOneSecond()
        status = .success
    }

    func populateParameters() async {
        status = .queryingParameters
        await sleepOneSecond()
        status = .clean
    }

    func fetch() async {
        status = .busy("Fetching...")
        await sleepOneSecond()
        status = .success
    }

    func send() async {
        status = .clean
    }
    
    func sendNode(deviceIndex: Int, path: [String]) async {
        status = .clean
    }
    
    func fetchNode(deviceIndex: Int, path: [String]) async {
        status = .clean
    }
}
