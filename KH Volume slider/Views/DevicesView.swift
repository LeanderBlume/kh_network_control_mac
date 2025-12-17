//
//  DevicesView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.02.25.
//

import SwiftUI

struct Device {
    let name: String
    let serialNumber: String
    let khAccess: KHAccess
    var sendEnabled: Bool = false
    
    func send() async throws {
        if sendEnabled {
            try await khAccess.send()
        }
    }
}

struct AllDevices {
    let devices: [Device]
    let controlAll: Bool

    func send() async throws {
        if controlAll {
            
        }
    }
}

struct DevicesView: View {
    @State var devices: [Device] = [
        Device(name: "asdf", serialNumber: "123", khAccess: KHAccess()),
        Device(name: "asdf2", serialNumber: "1233", khAccess: KHAccess())
    ]
    @State var selectedDevice: Int = 0
    @State var sendEnabled: [Bool] = [false, false]

    var body: some View {
        Picker("Display", selection: $selectedDevice) {
            ForEach(Array(zip(devices.indices, devices)), id: \.0) { index, device in
                HStack {
                    Text(device.name).tag(index)
                    Toggle("Control", isOn: $devices[index].sendEnabled)
                }
            }
        }
        .pickerStyle(InlinePickerStyle())
        
        //Toggle("Control all" isOn)
    }
}

#Preview {
    DevicesView()
}
