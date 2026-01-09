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
    case checkingSpeakerAvailability
    case speakersAvailable
    case speakersUnavailable
    case scanning
    case queryingParameters
    case speakersFound(Int)
    case success
    case otherError(String)

    func isClean() -> Bool {
        switch self {
        case .clean, .success, .speakersAvailable:
            return true
        case .speakersFound(let n):
            return n > 0
        default:
            return false
        }
    }

    func isBusy() -> Bool {
        switch self {
        case .fetching, .checkingSpeakerAvailability, .scanning, .queryingParameters:
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

protocol KHAccessProtocol: Observable, Identifiable {
    var state: KHState { get }
    var parameters: [SSCNode] { get }
    var status: KHAccessStatus { get }

    func scan(seconds: UInt32) async
    func setup() async
    func populateParameters() async
    func send() async
    func fetch() async
}

@Observable
final class KHAccessNative: KHAccessProtocol {
    /*
     Fetches, sends and stores data from speakers.
     */
    /// I was wondering whether we should just store a KHJSON instance instead of these values because the whole
    /// thing seems a bit doubled up. But maybe this is good as an abstraction layer between the json and the GUI.

    // UI state
    var state = KHState()
    // (last known) device state. We compare UI state against this to selectively send
    // changed values to the device.
    private var deviceState = KHState()

    var status: KHAccessStatus = .speakersFound(0)

    var devices: [SSCDevice] = []
    var parameters: [SSCNode] = []

    private func sendSSCValue<T>(path: [String], value: T) async throws
    where T: Encodable {
        for d in devices {
            try await d.sendSSCValue(path: path, value: value)
        }
    }

    private func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        return try await devices[0].fetchSSCValue(path: path)
    }

    private func connectAll() async {
        // TODO concurrency like in populateParameters
        for d in devices {
            do {
                try await d.connect()
            } catch SSCDevice.SSCDeviceError.noResponse {
                status = .speakersUnavailable
                return
            } catch {
                status = .otherError(String(describing: error))
            }
        }
        status = .success
    }

    private func disconnectAll() {
        for d in devices {
            d.disconnect()
        }
    }

    func scan(seconds: UInt32 = 1) async {
        /// Scan for devices, replacing current device list.
        status = .scanning
        devices = await SSCDevice.scan(seconds: seconds)
        for (i, d) in devices.enumerated() {
            parameters.append(SSCNode(device: d, name: "root \(i)"))
        }
        status = .speakersFound(devices.count)
    }

    func setup() async {
        status = .checkingSpeakerAvailability
        if devices.isEmpty {
            await scan()
        }
        if status == .speakersFound(0) {
            return
        }
        await fetch()
    }

    func populateParameters() async {
        if parameters.isEmpty {
            status = .speakersFound(0)
            return
        }
        await connectAll()
        status = .queryingParameters
        await withThrowingTaskGroup { group in
            for rootNode in parameters {
                group.addTask { try await rootNode.populate(recursive: true) }
            }
        }
        status = .success
        disconnectAll()
    }
    
    func fetch() async {
        status = .fetching
        await connectAll()
        if status != .success {
            return
        }
        do {
            try await fetchAux()
        } catch {
            // TODO
            status = .otherError("error fetching")
            disconnectAll()
            return
        }
        state = deviceState
        status = .success
        disconnectAll()
    }
    
    func send() async {
        // If nothing has changed, we don't even need to connect. Avoids excessive
        // connections DOSing the device.
        if state == deviceState {
            return
        }
        await connectAll()
        if status != .success {
            return
        }
        do {
            try await sendAux()
        } catch {
            // TODO
            status = .otherError("error sending")
            disconnectAll()
            return
        }
        deviceState = state
        disconnectAll()
    }

    /*
     DUMB AND BORING STUFF BELOW THIS COMMENT
    
     There must be a better way to do this. Create a struct with the UI values and
     associate a path to each one somehow. The values should know how to fetch
     themselves or something so we can add them more easily and modularly.
     */
    
    private func fetchAux() async throws {
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
    
    private func sendAux() async throws {
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
    var status: KHAccessStatus = .clean
    var parameters: [SSCNode] = []

    private func sleepOneSecond() async {
        do {
            try await Task.sleep(nanoseconds: 1000_000_000)
        } catch {
            status = .otherError("Sleeping failed")
        }
    }

    func scan(seconds: UInt32 = 1) async {
        status = .scanning
        await sleepOneSecond()
        status = .speakersFound(2)
    }

    func setup() async {
        status = .checkingSpeakerAvailability
        await sleepOneSecond()
        status = .speakersAvailable
    }

    func populateParameters() async {
        status = .queryingParameters
        await sleepOneSecond()
        status = .clean
    }

    func fetch() async {
        status = .fetching
        await sleepOneSecond()
        status = .success
    }

    func send() async {
        status = .clean
    }
}
