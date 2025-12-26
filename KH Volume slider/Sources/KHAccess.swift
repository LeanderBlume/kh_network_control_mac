//
//  KHAccessNative.swift
//  KH Volume slider
//
//  Created by Leander Blume on 31.03.25.
//

import SwiftUI

typealias KHAccess = KHAccessNative

struct KHAccessState: Equatable {
    var volume = 54.0
    var eqs = [Eq(numBands: 10), Eq(numBands: 20)]
    var muted = false
    var logoBrightness = 100.0
}

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
    init(devices devices_: [SSCDevice]?)

    var state: KHAccessState { get set }
    var parameters: [SSCNode] { get }
    var status: KHAccessStatus { get }

    func scan(scanTime: UInt32) async throws
    func checkSpeakersAvailable() async throws
    func send() async throws
    func fetch() async throws
}

@Observable
final class KHAccessNative: KHAccessProtocol {
    /*
     Fetches, sends and stores data from speakers.
     */
    /// I was wondering whether we should just store a KHJSON instance instead of these values because the whole
    /// thing seems a bit doubled up. But maybe this is good as an abstraction layer between the json and the GUI.

    // UI state
    var state = KHAccessState()
    // (last known) device state. We compare UI state against this to selectively send
    // changed values to the device.
    private var deviceState = KHAccessState()
    var parameters: [SSCNode] = []

    var status: KHAccessStatus = .clean

    private var devices: [SSCDevice]

    required init(devices devices_: [SSCDevice]? = nil) {
        if let devices_ = devices_ {
            devices = devices_
            return
        } else {
            devices = SSCDevice.scan()
        }
        parameters = devices.map { SSCNode(device: $0, name: "root") }
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

    func scan(scanTime: UInt32 = 1) async throws {
        /// Scan for devices, replacing current device list.
        status = .scanning
        devices = SSCDevice.scan(scanTime: scanTime)
        status = .speakersFound(devices.count)
    }

    private func connectAll() async throws {
        for d in devices {
            if d.connection.state != .ready {
                do {
                    try await d.connect()
                } catch SSCDevice.SSCDeviceError.noResponse {
                    status = .speakersUnavailable
                    throw KHAccessError.speakersNotReachable
                }
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

        deviceState.volume = try await fetchSSCValue(path: ["audio", "out", "level"])
        deviceState.muted = try await fetchSSCValue(path: ["audio", "out", "mute"])
        deviceState.logoBrightness = try await fetchSSCValue(path: [
            "ui", "logo", "brightness",
        ])
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            deviceState.eqs[eqIdx].boost = try await fetchSSCValue(path: [
                "audio", "out", eqName, "boost",
            ])
            deviceState.eqs[eqIdx].enabled = try await fetchSSCValue(path: [
                "audio", "out", eqName, "enabled",
            ])
            deviceState.eqs[eqIdx].frequency = try await fetchSSCValue(path: [
                "audio", "out", eqName, "frequency",
            ])
            deviceState.eqs[eqIdx].gain = try await fetchSSCValue(path: [
                "audio", "out", eqName, "gain",
            ])
            deviceState.eqs[eqIdx].q = try await fetchSSCValue(path: [
                "audio", "out", eqName, "q",
            ])
            deviceState.eqs[eqIdx].type = try await fetchSSCValue(path: [
                "audio", "out", eqName, "type",
            ])
        }

        state = deviceState

        status = .fetchingSuccess
        disconnectAll()
    }

    private func sendVolumeToDevice() async throws {
        try await sendSSCValue(
            path: ["audio", "out", "level"],
            value: Int(state.volume)
        )
    }

    private func sendEqBoost(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "boost"],
            value: state.eqs[eqIdx].boost
        )
    }

    private func sendEqEnabled(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "enabled"],
            value: state.eqs[eqIdx].enabled
        )
    }

    private func sendEqFrequency(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "frequency"],
            value: state.eqs[eqIdx].frequency
        )
    }

    private func sendEqGain(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "gain"],
            value: state.eqs[eqIdx].gain
        )
    }

    private func sendEqQ(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "q"],
            value: state.eqs[eqIdx].q
        )
    }

    private func sendEqType(eqIdx: Int, eqName: String) async throws {
        try await sendSSCValue(
            path: ["audio", "out", eqName, "type"],
            value: state.eqs[eqIdx].type
        )
    }

    private func sendMuteOrUnmute() async throws {
        try await sendSSCValue(path: ["audio", "out", "mute"], value: state.muted)
    }

    private func sendLogoBrightness() async throws {
        try await sendSSCValue(
            path: ["ui", "logo", "brightness"],
            value: state.logoBrightness
        )
    }

    func send() async throws {
        try await connectAll()

        if state.volume != deviceState.volume {
            try await sendVolumeToDevice()
        }
        if state.muted != deviceState.muted {
            try await sendMuteOrUnmute()
        }
        if state.logoBrightness != deviceState.logoBrightness {
            try await sendLogoBrightness()
        }
        for (eqIdx, eqName) in ["eq2", "eq3"].enumerated() {
            if state.eqs[eqIdx].boost != deviceState.eqs[eqIdx].boost {
                try await sendEqBoost(eqIdx: eqIdx, eqName: eqName)
            }
            if state.eqs[eqIdx].enabled != deviceState.eqs[eqIdx].enabled {
                try await sendEqEnabled(eqIdx: eqIdx, eqName: eqName)
            }
            if state.eqs[eqIdx].frequency != deviceState.eqs[eqIdx].frequency {
                try await sendEqFrequency(eqIdx: eqIdx, eqName: eqName)
            }
            if state.eqs[eqIdx].gain != deviceState.eqs[eqIdx].gain {
                try await sendEqGain(eqIdx: eqIdx, eqName: eqName)
            }
            if state.eqs[eqIdx].q != deviceState.eqs[eqIdx].q {
                try await sendEqQ(eqIdx: eqIdx, eqName: eqName)
            }
            if state.eqs[eqIdx].type != deviceState.eqs[eqIdx].type {
                try await sendEqType(eqIdx: eqIdx, eqName: eqName)
            }
        }

        deviceState = state

        disconnectAll()
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
    var state = KHAccessState()
    var status: KHAccessStatus = .clean

    required init(devices devices_: [SSCDevice]? = nil) {

    }

    private func sleepOneSecond() async throws {
        try await Task.sleep(nanoseconds: 1000_000_000)
    }

    func scan(scanTime: UInt32 = 1) async throws {
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
