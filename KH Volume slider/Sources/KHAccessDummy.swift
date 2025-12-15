//
//  KHAccessDummy.swift
//  KH Volume slider
//
//  Created by Leander Blume on 15.12.25.
//

import SwiftUI


@Observable
class KHAccessDummy {
    /*
     Fetches, sends and stores data from speakers.
     */
    /// I was wondering whether we should just store a KHJSON instance instead of these values because the whole
    /// thing seems a bit doubled up. But maybe this is good as an abstraction layer between the json and the GUI.

    // UI state
    var volume = 54.0
    var eqs = [Eq(numBands: 10), Eq(numBands: 20)]
    var muted = false
    var logoBrightness = 100.0

    var status: Status = .clean
    var devices: [SSCDevice]

    init(devices devices_: [SSCDevice]? = nil) {
        devices = []
    }

    enum Status {
        case clean
        case fetching
        case fetchingSuccess
        case checkingSpeakerAvailability
        case speakersAvailable
        case speakersUnavailable
        case scanning
        case speakersFound
        case noSpeakersFoundDuringScan

        func isClean() -> Bool {
            let cleanyVals: [Status] = [
                .clean, .fetchingSuccess, .speakersAvailable, .speakersFound,
            ]
            if cleanyVals.contains(self) {
                return true
            } else {
                return false
            }
        }
    }

    enum KHAccessError: Error {
        case speakersNotReachable
        case noSpeakersFoundDuringScan
    }
    
    private func sleepOneSecond() async throws {
        try await Task.sleep(nanoseconds: 1000_000_000)
    }

    func sendSSCValue<T>(path: [String], value: T) async throws where T: Encodable {
        for d in devices {
            try d.sendSSCValue(path: path, value: value)
        }
    }

    func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        return 0 as! T
    }

    func clearDevices() {
    }

    private func scan() async throws {
        /// Scan for devices, replacing current device list.
        status = .scanning
        // try await sleepOneSecond()
        status = .speakersFound
    }

    private func connectAll() async throws {
        status = .clean
    }

    private func disconnectAll() {
    }

    func checkSpeakersAvailable() async throws {
        status = .checkingSpeakerAvailability
        try await sleepOneSecond()
        status = .clean
    }

    /*
     DUMB AND BORING STUFF BELOW THIS COMMENT
    
     There must be a better way to do this. Create a struct with the UI values and
     associate a path to each one somehow. The values should know how to fetch
     themselves or something so we can add them more easily and modularly.
     */

    func fetch() async throws {
        status = .fetching
        try await sleepOneSecond()
        status = .fetchingSuccess
        // status = .clean
    }

    func send() async throws {
    }
}
