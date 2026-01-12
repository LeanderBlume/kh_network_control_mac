//
//  KH_Volume_sliderTests.swift
//  KH Volume sliderTests
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import Testing

@testable import KH_Volume_slider

@MainActor
struct KH_Volume_sliderTests_Online {
    @Test func testSendToDevice() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let khAccess = KHAccess()
        await khAccess.fetch()
        await khAccess.send()
    }
}

struct KH_Volume_sliderTests_Offline {
    @Test func testReadFromBackup() async throws {
        #expect(true)
    }
}

struct TestSSC {
    /*
    // Private
    @Test func testSendMessageWithScan() async throws {
        let sscDevice = SSCDevice.scan()[0]
        try await sscDevice.connect()

        let TX1 = "{\"audio\":{\"out\":{\"mute\":true}}}"
        await sscDevice.sendMessage(TX1)
        let RX1 = try await sscDevice.receiveMessage()
        #expect(RX1.starts(with: TX1))

        let TX2 = "{\"audio\":{\"out\":{\"mute\":false}}}"
        await sscDevice.sendMessage(TX2)
        let RX2 = try await sscDevice.receiveMessage()
        #expect(RX2.starts(with: TX2))
        sscDevice.disconnect()
    }
     */

    @Test func testScan() async {
        let s = await SSCConnection.scan()
        #expect(!s.isEmpty)
    }

    // This should be a SwiftSSC test.
    @Test func testFetchSSCValue() async throws {
        let sscDevice = await SSCConnection.scan()[0]
        try await sscDevice.open()
        let response: Bool = try await sscDevice.fetchSSCValue(path: [
            "audio", "out", "mute",
        ])
        #expect(response == false)
        sscDevice.close()
    }
    
    @Test func testSendSSCValue() async throws {
        let sscDevice = await SSCConnection.scan()[0]
        try await sscDevice.open()
        try await sscDevice.sendSSCValue(path: [
            "audio", "out", "mute",
        ], value: true)
        sleep(1)
        try await sscDevice.sendSSCValue(path: [
            "audio", "out", "mute",
        ], value: false)
        sscDevice.close()
    }
}

@MainActor
struct TestKHAccessDummy {
    @Test func testSetup() {
        let k = KHAccessDummy()
        // This doesn't make sense but it's the way it is.
        #expect(k.status == .clean)
    }

    @Test func testScan() async throws {
        let k = KHAccessDummy()
        await k.scan()
        #expect(k.status == .speakersFound(2))
    }

    @Test func testCheckSpeakersAvailable() async throws {
        let k = KHAccessDummy()
        await k.setup()
        // #expect(k.status == .speakersAvailable)
    }

    @Test func testFetch() async throws {
        let k = KHAccessDummy()
        await k.fetch()
        #expect(k.status == .success)
    }

    @Test func testSend() async throws {
        let k = KHAccessDummy()
        await k.send()
        #expect(k.status == .clean)
    }
}

@MainActor
@Suite struct TestSSCNodes {
    // TODO can't run this as a test suite because tests are run concurrently.
    let connection: SSCConnection

    private enum Errors: Error {
        case noDevicesFound
    }

    private init() async throws {
        let scan = await SSCConnection.scan()
        if scan.isEmpty {
            throw Errors.noDevicesFound
        }
        connection = scan[0]
    }

    @Test func testGetSchema() async throws {
        let node = SSCNode(connection: connection, name: "root")
        // try await node.connect()
        let result = try await node.getSchema(path: ["audio"])
        #expect(result == ["out": [:], "in2": [:], "in1": [:], "in": [:]])
        sleep(1)
        let result2 = try await node.getSchema(path: [])
        #expect(
            result2 == [
                "audio": [:], "device": [:], "m": [:], "osc": [:], "ui": [:],
                "warnings": nil,
            ]
        )
        sleep(1)
        let result3 = try await node.getSchema(path: ["ui", "logo", "brightness"])
        #expect(result3 == nil)
        // node.disconnect()
    }

    @Test func testGetLimits() async throws {
        let node = SSCNode(connection: connection, name: "root")
        // try await node.connect()
        let result = try await node.getLimits(path: ["ui", "logo", "brightness"])
        print(result)
        #expect(
            result
                == OSCLimits(fromDict: [
                    "type": "Number",
                    "units": "%",
                    "max": 125.0,
                    "min": 0.0,
                    "inc": 1.0,
                    "subscr": true,
                    // "const": nil,
                    "desc": nil,
                    "writeable": nil,
                ])
        )
        // node.disconnect()
    }

    @Test func testPopulate() async throws {
        let node = SSCNode(connection: connection, name: "root")
        // try await node.connect()
        #expect(node.pathToNode() == [])
        try await node.populate()
        // node.disconnect()
    }
}

struct TestGenericType {
    @Test func main() {

        class BlaType<T> {
            var value: T

            init(_ v: T) {
                value = v
            }
        }

        _ = BlaType(3)
        let _: BlaType<BlaType<Int>> = BlaType(BlaType(3))
        let _: BlaType<[BlaType<Int>]> = BlaType([BlaType(3)])
    }
}
