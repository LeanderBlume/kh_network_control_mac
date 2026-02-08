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
        let pv = ProgressView()
            #if os(macOS)
                .scaleEffect(0.5)
            #endif
        let circ = Image(systemName: "circle.fill")
        switch status {
        case .ready:
            circ.foregroundColor(.green)
        case .busy:
            pv
        case .error:
            Image(systemName: "exclamationmark.circle").foregroundColor(.red)
        }
    }
}

// This could be a function of Status returning String?
struct StatusDisplayText: View {
    var status: KHDeviceStatus

    var body: some View {
        switch status {
        case .ready: Text("Ready")
        case .busy(let s), .error(let s): Text(s)
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
