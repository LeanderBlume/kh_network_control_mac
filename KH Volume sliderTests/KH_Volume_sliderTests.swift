//
//  KH_Volume_sliderTests.swift
//  KH Volume sliderTests
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import Testing
@testable import KH_Volume_slider

struct KH_Volume_sliderTests_Online {
    @Test func testSendToDevice() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let khAccess = KHAccess()
        try await khAccess.fetch()
        try await khAccess.send()
    }
}

struct KH_Volume_sliderTests_Offline {
    @Test func testReadFromBackup() async throws {
        #expect(true)
    }
}

struct TestSSC {
    @Test func testSendMessage() {
        let ip = "fe80::2a36:38ff:fe61:7933"
        guard let sscDevice = SSCDevice(ip: ip) else {
            #expect(Bool(false))
            return
        }
        sscDevice.connect()
        while sscDevice.connection.state != .ready {
            print(sscDevice.connection.state)
            sleep(1)
        }
        #expect(sscDevice.connection.state == .ready)

        let TX1 = "{\"audio\":{\"out\":{\"mute\":true}}}"
        let t1 = sscDevice.sendMessage(TX1)
        while t1.RX.isEmpty {}
        #expect(t1.TX == TX1)
        #expect(t1.RX.starts(with: TX1))
        
        let TX2 = "{\"audio\":{\"out\":{\"mute\":false}}}"
        let t2 = sscDevice.sendMessage(TX2)
        while t2.RX.isEmpty {}
        #expect(t2.TX == TX2)
        #expect(t2.RX.starts(with: TX2))
        sscDevice.disconnect()
    }

    @Test func testSendMessageWithScan() {
        let sscDevice = SSCDevice.scan()[0]
        sscDevice.connect()
        
        let TX1 = "{\"audio\":{\"out\":{\"mute\":true}}}"
        let t1 = sscDevice.sendMessage(TX1)
        sleep(1)
        #expect(t1.TX == TX1)
        #expect(t1.RX.starts(with: TX1))
        
        let TX2 = "{\"audio\":{\"out\":{\"mute\":false}}}"
        let t2 = sscDevice.sendMessage(TX2)
        sleep(1)
        #expect(t2.TX == TX2)
        #expect(t2.RX.starts(with: TX2))
        sscDevice.disconnect()
    }

    @Test func testScan() {
        let s = SSCDevice.scan()
        #expect(!s.isEmpty)
    }

    @Test func testPathToJSONString() throws {
        // let js1 = try KHAccess.pathToJSONString(path: ["a", "b"], value: 0)
        // #expect(js1 == "{\"a\":{\"b\":0}}")
        // let js2 = try KHAccess.pathToJSONString(path: ["a", "b"], value: nil as Float?)
        // #expect(js2 == "{\"a\":{\"b\":null}}")
    }

    @Test func testFetchSSCValue() async throws {
        let khAccess = KHAccess()
        sleep(1)
        try await khAccess.checkSpeakersAvailable()
        sleep(1)
        let result: Bool = try await khAccess.fetchSSCValue(path: ["audio", "out", "mute"])
        #expect(result == false)
        khAccess.devices.forEach { d in
            d.disconnect()
        }
    }
}
