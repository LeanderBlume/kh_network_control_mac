//
//  AppModel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 09.04.26.
//

struct StateManager {
    var khAccess: KHAccess

    var commonState = KHState(deviceID: nil)
    var deviceStates = [KHState]()

    mutating func setup() async {
        await khAccess.setup()
        await fetch()
    }

    mutating func syncDeviceStatesToCommon() {
        guard !deviceStates.isEmpty else { return }
        for p in SSCParameter.allDefaultParameters {
            if p.allEqual(deviceStates) {
                commonState = p.copy(from: deviceStates.first!, into: commonState)
            }
        }
    }

    mutating func syncCommonToDeviceStates(_ p: SSCParameter) {
        deviceStates = deviceStates.map { state in
            p.copy(from: commonState, into: state)
        }
    }

    mutating func fetch() async {
        deviceStates = await khAccess.fetchAll().sorted(by: { $0.name < $1.name })
        syncDeviceStatesToCommon()
    }

    mutating func rescan() async {
        await khAccess.scan()
        await setup()
    }

    mutating func clearCache() async {
        do {
            try SchemaCache().clear()
            try StateCache().clear()
        } catch {
            print("Failed to clear cache with error:", error)
            return
        }
        await setup()
    }

    mutating func sendToAll(_ parameter: SSCParameter) async {
        syncCommonToDeviceStates(parameter)
        await khAccess.sendIndividual(deviceStates)
    }

    mutating func sendIndividual() async {
        await khAccess.sendIndividual(deviceStates)
        syncDeviceStatesToCommon()
    }
}
