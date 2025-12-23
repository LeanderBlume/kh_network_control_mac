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
    case fetching
    case fetchingSuccess
    case checkingSpeakerAvailability
    case speakersAvailable
    case speakersUnavailable
    case scanning
    case speakersFound(Int)

    func isClean() -> Bool {
        switch self {
        case .clean, .fetchingSuccess, .speakersAvailable:
            return true
        case .speakersFound(let n):
            return n > 0
        default:
            return false
        }
    }

    func isBusy() -> Bool {
        switch self {
        case .fetching, .checkingSpeakerAvailability, .scanning:
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

protocol KHAccessProtocol: Observable {
    var volume: Double { get set }
    var eqs: [Eq] { get set }
    var muted: Bool { get set }
    var logoBrightness: Double { get set }

    var status: KHAccessStatus { get }

    init(devices devices_: [SSCDevice]?)

    func scan() async throws
    func checkSpeakersAvailable() async throws
    func send() async throws
    func fetch() async throws
}

@Observable
class KHAccessNative: KHAccessProtocol {
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

    // (last known) device state. We compare UI state against this to selectively send
    // changed values to the device.
    private var volumeDevice = 54.0
    private var eqsDevice = [Eq(numBands: 10), Eq(numBands: 20)]
    private var mutedDevice = false
    private var logoBrightnessDevice = 100.0

    var status: KHAccessStatus = .clean
    private var devices: [SSCDevice]

    required init(devices devices_: [SSCDevice]? = nil) {
        if let devices_ = devices_ {
            devices = devices_
            return
        } else {
            devices = SSCDevice.scan()
        }
    }

    private func sendSSCValue<T>(path: [String], value: T) async throws
    where T: Encodable {
        for d in devices {
            try d.sendSSCValue(path: path, value: value)
        }
    }

    private func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        return try devices[0].fetchSSCValue(path: path)
    }

    func scan() async throws {
        /// Scan for devices, replacing current device list.
        status = .scanning
        devices = SSCDevice.scan()
        status = .speakersFound(devices.count)
    }

    private func connectAll() async throws {
        /// TODO why is the deadline stuff not happening in SSCDevice?
        for d in devices {
            if d.connection.state != .ready {
                d.connect()
            }
            let deadline = Date.now.addingTimeInterval(5)
            var success = false
            while Date.now < deadline {
                if d.connection.state == .ready {
                    success = true
                    break
                }
            }
            if !success {
                print("timed out, could not connect")
                status = .speakersUnavailable
                throw KHAccessError.speakersNotReachable
            }
        }
    }

    private func disconnectAll() {
        for d in devices {
            d.disconnect()
        }
    }

    func checkSpeakersAvailable() async throws {
        status = .checkingSpeakerAvailability
        if devices.isEmpty {
            try await scan()
        }
        if case .speakersFound(let n) = status {
            if n == 0 {
                return
            }
        }
        try await connectAll()
        status = .speakersAvailable
        disconnectAll()
    }

    /*
     DUMB AND BORING STUFF BELOW THIS COMMENT
    
     There must be a better way to do this. Create a struct with the UI values and
     associate a path to each one somehow. The values should know how to fetch
     themselves or something so we can add them more easily and modularly.
     */

    func fetch() async throws {
        status = .fetching
        try await connectAll()

        volumeDevice = try await fetchSSCValue(path: ["audio", "out", "level"])
        mutedDevice = try await fetchSSCValue(path: ["audio", "out", "mute"])
        logoBrightnessDevice = try await fetchSSCValue(path: [
            "ui", "logo", "brightness",
        ])
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            eqsDevice[eqIdx].boost = try await fetchSSCValue(path: [
                "audio", "out", eqName, "boost",
            ])
            eqsDevice[eqIdx].enabled = try await fetchSSCValue(path: [
                "audio", "out", eqName, "enabled",
            ])
            eqsDevice[eqIdx].frequency = try await fetchSSCValue(path: [
                "audio", "out", eqName, "frequency",
            ])
            eqsDevice[eqIdx].gain = try await fetchSSCValue(path: [
                "audio", "out", eqName, "gain",
            ])
            eqsDevice[eqIdx].q = try await fetchSSCValue(path: [
                "audio", "out", eqName, "q",
            ])
            eqsDevice[eqIdx].type = try await fetchSSCValue(path: [
                "audio", "out", eqName, "type",
            ])
        }

        volume = volumeDevice
        muted = mutedDevice
        logoBrightness = logoBrightnessDevice
        eqs = eqsDevice

        status = .fetchingSuccess
        disconnectAll()
    }

    private func sendVolumeToDevice() async throws {
        try await sendSSCValue(path: ["audio", "out", "level"], value: Int(volume))
    }

    private func sendEqBoost(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "boost"],
            value: eqs[eqIdx].boost
        )
    }

    private func sendEqEnabled(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "enabled"],
            value: eqs[eqIdx].enabled
        )
    }

    private func sendEqFrequency(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "frequency"],
            value: eqs[eqIdx].frequency
        )
    }

    private func sendEqGain(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "gain"],
            value: eqs[eqIdx].gain
        )
    }

    private func sendEqQ(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "q"],
            value: eqs[eqIdx].q
        )
    }

    private func sendEqType(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "type"],
            value: eqs[eqIdx].type
        )
    }

    private func sendMuteOrUnmute() async throws {
        try await sendSSCValue(path: ["audio", "out", "mute"], value: muted)
    }

    private func sendLogoBrightness() async throws {
        try await sendSSCValue(
            path: ["ui", "logo", "brightness"],
            value: logoBrightness
        )
    }

    func send() async throws {
        try await connectAll()

        if volume != volumeDevice {
            try await sendVolumeToDevice()
            volumeDevice = volume
        }
        if muted != mutedDevice {
            try await sendMuteOrUnmute()
            mutedDevice = muted
        }
        if logoBrightness != logoBrightnessDevice {
            try await sendLogoBrightness()
            logoBrightnessDevice = logoBrightness
        }
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            if eqs[eqIdx].boost != eqsDevice[eqIdx].boost {
                try await sendEqBoost(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].boost = eqs[eqIdx].boost
            }
            if eqs[eqIdx].enabled != eqsDevice[eqIdx].enabled {
                try await sendEqEnabled(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].enabled = eqs[eqIdx].enabled
            }
            if eqs[eqIdx].frequency != eqsDevice[eqIdx].frequency {
                try await sendEqFrequency(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].frequency = eqs[eqIdx].frequency
            }
            if eqs[eqIdx].gain != eqsDevice[eqIdx].gain {
                try await sendEqGain(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].gain = eqs[eqIdx].gain
            }
            if eqs[eqIdx].q != eqsDevice[eqIdx].q {
                try await sendEqQ(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].q = eqs[eqIdx].q
            }
            if eqs[eqIdx].type != eqsDevice[eqIdx].type {
                try await sendEqType(eqIdx: eqIdx, eqName: eqName)
                eqsDevice[eqIdx].type = eqs[eqIdx].type
            }
        }

        disconnectAll()
    }
}

@Observable
class KHAccessDummy: KHAccessProtocol {
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

    var status: KHAccessStatus = .clean

    required init(devices devices_: [SSCDevice]? = nil) {

    }

    private func sleepOneSecond() async throws {
        try await Task.sleep(nanoseconds: 1000_000_000)
    }

    func scan() async throws {
        status = .scanning
        try await sleepOneSecond()
        status = .speakersFound(2)
    }

    func checkSpeakersAvailable() async throws {
        status = .checkingSpeakerAvailability
        try await sleepOneSecond()
        status = .speakersAvailable
    }

    func fetch() async throws {
        status = .fetching
        try await sleepOneSecond()
        status = .fetchingSuccess
    }

    func send() async throws {
        status = .clean
    }
}
