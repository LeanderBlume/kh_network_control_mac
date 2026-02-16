//
//  StatusDisplay.swift
//  KH Volume slider
//
//  Created by Leander Blume on 17.01.25.
//

import SwiftUI

struct StatusDisplayCompact: View {
    var status: KHDeviceStatus

    var body: some View {
        switch status {
        case .ready:
            Image(systemName: "circle.fill").foregroundColor(.green)
        case .busy:
            ProgressView()
                #if os(macOS)
                    .scaleEffect(0.5)
                #endif
        case .error:
            Image(systemName: "exclamationmark.circle").foregroundColor(.red)
        }
    }
}

struct StatusDisplayText: View {
    var status: KHDeviceStatus

    var body: some View {
        switch status {
        case .ready:
            Text("Ready")
        case .busy(let s),.error(let s):
            Text(s)
        }
    }
}

struct StatusDisplay: View {
    var status: KHDeviceStatus

    var body: some View {
        HStack {
            StatusDisplayCompact(status: status)
            StatusDisplayText(status: status)
        }
        .frame(height: 20)
        .frame(minWidth: 33)
    }
}
