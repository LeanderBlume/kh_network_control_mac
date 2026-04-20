//
//  AppModel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 09.04.26.
//

import SwiftUI

@Observable
@MainActor
class StateManager {
    var commonState = KHState(deviceID: nil)
    var deviceStates = [KHState]()

    let khAccess: KHAccess

    init(_ khAccess: KHAccess) { self.khAccess = khAccess }

    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    func syncDeviceStatesToCommon() {
        guard !deviceStates.isEmpty else { return }
        for p in SSCParameter.allDefaultParameters {
            if p.allEqual(deviceStates) {
                commonState = p.copy(from: deviceStates.first!, into: commonState)
            }
        }
    }

    func syncCommonToDeviceStates(_ p: SSCParameter) {
        deviceStates = deviceStates.map { state in
            p.copy(from: commonState, into: state)
        }
    }

    func fetch() async {
        deviceStates = await khAccess.fetchAll().sorted(by: { $0.name < $1.name })
        syncDeviceStatesToCommon()
    }

    func rescan() async {
        await khAccess.scan()
        await setup()
    }

    func clearCache() async {
        do {
            try SchemaCache().clear()
            try StateCache().clear()
        } catch {
            print("Failed to clear cache with error:", error)
            return
        }
        await setup()
    }

    func sendToAll(_ parameter: SSCParameter) async {
        syncCommonToDeviceStates(parameter)
        await khAccess.sendIndividual(deviceStates)
    }

    func sendIndividual() async {
        await khAccess.sendIndividual(deviceStates)
        syncDeviceStatesToCommon()
    }
}
