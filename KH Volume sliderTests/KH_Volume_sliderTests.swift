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
    @Test func testJsonPath() async throws {
        let s = try SSCConnection.pathToJSONString(path: ["asdf", "jkl"], value: 3.0)
        #expect(s == "{\"asdf\":{\"jkl\":3}}")
    }

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

    @Test func testService() async throws {
        let s = await SSCConnection.scan()
        #expect(!s.isEmpty)
        if let service = await s.first!.service {
            print(service)
            let newC = SSCConnection(
                serviceName: service.0,
                type: service.1,
                domain: service.2
            )
            try await newC.open()
            let response: Bool = try await newC.fetchSSCValue(path: [
                "audio", "out", "mute",
            ])
            #expect(response == false)
            await newC.close()
        }
    }

    // This should be a SwiftSSC test.
    @Test func testFetchSSCValue() async throws {
        let sscDevice = await SSCConnection.scan()[0]
        try await sscDevice.open()
        let response: Bool = try await sscDevice.fetchSSCValue(path: [
            "audio", "out", "mute",
        ])
        #expect(response == false)
        await sscDevice.close()
    }

    @Test func testSendSSCValue() async throws {
        let sscDevice = await SSCConnection.scan()[0]
        try await sscDevice.open()
        try await sscDevice.sendSSCValue(
            path: [
                "audio", "out", "mute",
            ],
            value: true
        )
        sleep(1)
        try await sscDevice.sendSSCValue(
            path: [
                "audio", "out", "mute",
            ],
            value: false
        )
        await sscDevice.close()
    }
}

@MainActor
@Suite struct TestSSCNodes {
    // TODO can't run this as a test suite because tests are run concurrently.
    let connection: SSCConnection
    let deviceID = KHDevice.KHDeviceID(name: "asdf", serial: "jkl")

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
        let node = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        // try await node.connect()
        let result = try await node.getSchema(connection: connection, path: ["audio"])
        #expect(result == ["out": [:], "in2": [:], "in1": [:], "in": [:]])
        sleep(1)
        let result2 = try await node.getSchema(connection: connection, path: [])
        #expect(
            result2 == [
                "audio": [:], "device": [:], "m": [:], "osc": [:], "ui": [:],
                "warnings": nil,
            ]
        )
        sleep(1)
        let result3 = try await node.getSchema(
            connection: connection,
            path: ["ui", "logo", "brightness"]
        )
        #expect(result3 == nil)
        // node.disconnect()
    }

    @Test func testGetLimits() async throws {
        let node = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        // try await node.connect()
        let result = try await node.getLimits(
            connection: connection,
            path: ["ui", "logo", "brightness"]
        )
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
        let node = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        try await connection.open()
        #expect(node.pathToNode() == [])
        try await node.populate(connection: connection)
        await connection.close()
    }

    @Test func testIteration() async throws {
        let node = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        try await connection.open()
        #expect(node.pathToNode() == [])
        try await node.populate(connection: connection)
        await connection.close()
        let names = node.map(\.name)
        // Not the root node!
        #expect(!names.contains("root"))
        // Internal node
        #expect(names.contains("ui"))
        // Leaf node
        #expect(names.contains("brightness"))
        node.map({ $0.pathToNode() }).forEach { print($0) }
    }

    @Test func testSend() async throws {
        let node1 = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        let node2 = SSCNode(name: "device", deviceID: deviceID, parent: node1)
        let leaf = SSCNode(name: "name", deviceID: deviceID, parent: node2)
        #expect(leaf.pathToNode() == ["device", "name"])
        leaf.value = NodeData(value: "New name!")
        try await connection.open()
        // try await leaf.sendLeaf(connection: connection)
        await connection.close()
    }
    
    @Test func testGetAtPath() async throws {
        let root = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        let node2 = SSCNode(name: "device", deviceID: deviceID, parent: root)
        root.value = .children([node2])
        let leaf = SSCNode(name: "name", deviceID: deviceID, parent: node2)
        node2.value = .children([leaf])
        #expect(leaf.pathToNode() == ["device", "name"])
        #expect(root.getAtPath([])!.name == "root")
        #expect(root.getAtPath(["device"])!.name == "device")
        #expect(root.getAtPath(["device", "name"])!.name == "name")
        #expect(root.getAtPath(["device", "asf"]) == nil)
    }

    @Test func testDecoding() async throws {
        let rootNode = SSCNode(name: "root", deviceID: deviceID, parent: nil)
        try await connection.open()
        #expect(rootNode.pathToNode() == [])
        try await rootNode.populate(connection: connection)
        await connection.close()
        let treeData = JSONData(fromNodeTree: rootNode)!
        let jd = try JSONEncoder().encode(treeData)
        let decoder = JSONDecoder()
        let schema = JSONData(fromNodeTree: rootNode)
        // decoder.userInfo[.schemaJSONData] = schema
        let decodedTest = try decoder.decode(
            JSONData.self,
            from: jd,
            configuration: schema!
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let reencoded = try encoder.encode(decodedTest)
        print(String(data: reencoded, encoding: .utf8)!)
        try rootNode.load(jsonData: treeData)
    }
}

struct TestJSONEncoding {
    func encode<T>(_ value: T) throws -> String where T: Encodable {
        let jsonData = try! JSONEncoder().encode(value)
        return String(data: jsonData, encoding: .utf8)!
    }

    @Test func testEncoding() throws {
        let s = JSONData.string("asdf / jkl")
        print(try encode(s))

        let s2 = "asdf / jkl"
        let s2d = try encode(s2).data(using: .utf8)!
        print(try! encode(s2))
        let x = try JSONDecoder().decode(String.self, from: s2d)
        print(x)

        let s3 = JSONData.array([.string("A/C"), .string("B")])
        print(try! encode(s3))
        let s3d = try encode(s3).data(using: .utf8)!
        print(try! encode(s2))
        let x2 = try JSONDecoder().decode([String].self, from: s3d)
        print(x2)
    }
}

struct TestKHParameter {
    @Test func main() {
        let vol = KHParameters.volume
        #expect(vol.getDevicePath() == ["audio", "out", "level"])
        vol.setDevicePath(to: ["bla", "blub"])
        #expect(vol.getDevicePath() == ["bla", "blub"])
        vol.resetDevicePath()
    }
}
