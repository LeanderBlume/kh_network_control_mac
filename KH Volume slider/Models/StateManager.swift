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
    var deviceStates = [KHState]() {
        didSet { syncDeviceStatesToCommon() }
    }

    let khAccess: KHAccess

    init(_ khAccess: KHAccess) { self.khAccess = khAccess }

    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    private func syncDeviceStatesToCommon() {
        guard !deviceStates.isEmpty else { return }
        for p in SSCParameter.allDefaultParameters {
            if p.allEqual(deviceStates) {
                commonState = p.copy(from: deviceStates.first!, into: commonState)
            }
        }
    }

    private func syncCommonToDeviceStates(_ p: SSCParameter) {
        deviceStates = deviceStates.map { state in
            p.copy(from: commonState, into: state)
        }
    }

    func fetch() async {
        /// Sorting is just for consistency in the UI. Functionality doesn't depend on this order.
        deviceStates = await khAccess.fetchAll().sorted(by: { $0.name < $1.name })
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
    }
}
