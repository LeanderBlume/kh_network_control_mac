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

    init(_ state: KHState)

    func description() -> String

    func getDevicePath(for: KHParameters2) -> [String]
    func setDevicePath(for: KHParameters2, to path: [String]?)
    func resetDevicePath(for: KHParameters2)
    func resetAllDevicePaths()
}

struct DeviceModel: DeviceModelProtocol {
    let product: String
    let version: String
    
    var id: String { description() }

    init(_ state: KHState) {
        product = state.product
        version = state.version
    }

    func description() -> String { product + " / " + version }

    private static func getPathDict() -> ParameterPathDict? {
        let decoder = JSONDecoder()
        guard let data: Data = AppStorage("paths").wrappedValue else {
            return nil
        }
        return try? decoder.decode(ParameterPathDict.self, from: data)
    }

    func getDevicePath(for parameter: KHParameters2) -> [String] {
        Self.getPathDict()?[self]?[parameter.id]
            ?? parameter.getDevicePathFallback()
    }
    
    func getPathString(for parameter: KHParameters2) -> String {
        "/" + getDevicePath(for: parameter).joined(separator: "/")
    }
    
    func setDevicePath(for parameter: KHParameters2, to path: [String]?) {
        guard var topDict = Self.getPathDict() else {
            print("Error getting path dict when setting")
            return
        }
        var modelDict = topDict[self] ?? [String: [String]]()
        modelDict[parameter.id] = path
        topDict[self] = modelDict
        guard let data = try? JSONEncoder().encode(topDict) else {
            print("Error encoding path dict when setting")
            return
        }
        AppStorage("paths").wrappedValue = data
    }

    func resetDevicePath(for parameter: KHParameters2) {
        setDevicePath(for: parameter, to: nil)
    }

    func resetAllDevicePaths() {
        KHParameters2.allCases.forEach { resetDevicePath(for: $0) }
    }
}
