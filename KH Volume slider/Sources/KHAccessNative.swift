//
//  KHAccessNative.swift
//  KH Volume slider
//
//  Created by Leander Blume on 31.03.25.
//

import SwiftUI

@Observable
class KHAccessNative {
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

    var status: Status = .clean
    var devices: [SSCDevice]

    init(devices devices_: [SSCDevice]? = nil) {
        if let devices_ = devices_ {
            devices = devices_
            return
        } else {
            devices = SSCDevice.scan()
        }
    }

    enum Status {
        case clean
        case fetching
        case checkingSpeakerAvailability
        case speakersUnavailable
        case scanning
        case noSpeakersFoundDuringScan
    }

    enum KHAccessError: Error {
        case speakersNotReachable
        case noSpeakersFoundDuringScan
    }

    func sendSSCValue<T>(path: [String], value: T) async throws where T: Encodable {
        for d in devices {
            try d.sendSSCValue(path: path, value: value)
        }
    }

    func fetchSSCValue<T>(path: [String]) async throws -> T where T: Decodable {
        return try devices[0].fetchSSCValue(path: path)
    }
    
    func clearDevices() {
        devices.removeAll()
    }

    private func scan() async throws {
        /// Scan for devices, replacing current device list.
        status = .scanning
        devices = SSCDevice.scan()
        if devices.isEmpty {
            status = .noSpeakersFoundDuringScan
            throw KHAccessError.noSpeakersFoundDuringScan
        } else {
            status = .clean
        }
    }

    private func connectAll() async throws {
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
        status = .clean
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
        try await connectAll()
        status = .clean
        try await fetch()
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

        disconnectAll()
        status = .clean
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
