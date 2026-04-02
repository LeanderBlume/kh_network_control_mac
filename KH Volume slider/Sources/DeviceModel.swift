//
//  DeviceModel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 25.03.26.
//
import SwiftUI

protocol DeviceModelProtocol: Codable, Hashable, Identifiable {
    var product: String { get }
    var version: String { get }

    init(_ device: KHDevice)

    func description() -> String

    func getDevicePath(for: KHParameters) -> [String]
    func setDevicePath(for: KHParameters, to path: [String]?)
    func resetDevicePath(for: KHParameters)
    func resetAllDevicePaths()
}

struct DeviceModel: DeviceModelProtocol {
    let product: String
    let version: String

    var id: String { description() }

    init(_ device: KHDevice) {
        product = device.product
        version = device.version
    }

    func description() -> String { product + " / " + version }

    func numEqs() -> Int {
        switch (product, version) {
        case ("KH 120 II", "1_1_14"): fallthrough
        default: 2
        }
    }

    func eqName(_ eqIndex: Int) -> String {
        let names =
            switch (product, version) {
            case ("KH 120 II", "1_1_14"): fallthrough
            default: ["eq2", "eq3"]
            }
        return names[eqIndex]
    }

    func allParameters() -> [KHParameters] {
        switch (product, version) {
        case ("KH 120 II", "1_1_14"): fallthrough
        default:
            var result: [KHParameters] = [
                .name,
                .volume,
                .muted,
                .logoBrightness,
                .standbyEnabled,
                .standbyTimeout,
                .delay,
                .identify,
            ]
            for i in 0..<numEqs() {
                for p in EQParameters.allCases {
                    result.append(.eq(i, eqName(i), p))
                }
            }
            return result
        }

    }

    private static func getPathDict() -> ParameterPathDict? {
        let decoder = JSONDecoder()
        guard let data: Data = AppStorage("paths").wrappedValue else {
            return nil
        }
        return try? decoder.decode(ParameterPathDict.self, from: data)
    }

    func getDevicePath(for parameter: KHParameters) -> [String] {
        Self.getPathDict()?[self]?[parameter.description()]
            ?? parameter.getDevicePathFallback()
    }

    func getPathString(for parameter: KHParameters) -> String {
        "/" + getDevicePath(for: parameter).joined(separator: "/")
    }

    func setDevicePath(for parameter: KHParameters, to path: [String]?) {
        guard var topDict = Self.getPathDict() else {
            print("Error getting path dict when setting")
            return
        }
        var modelDict = topDict[self] ?? [String: [String]]()
        modelDict[parameter.description()] = path
        topDict[self] = modelDict
        guard let data = try? JSONEncoder().encode(topDict) else {
            print("Error encoding path dict when setting")
            return
        }
        AppStorage("paths").wrappedValue = data
    }

    func resetDevicePath(for parameter: KHParameters) {
        setDevicePath(for: parameter, to: nil)
    }

    func resetAllDevicePaths() {
        allParameters().forEach { resetDevicePath(for: $0) }
    }
}
