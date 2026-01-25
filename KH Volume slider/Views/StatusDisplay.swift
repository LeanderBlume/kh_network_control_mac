//
//  StatusDisplay.swift
//  KH Volume slider
//
//  Created by Leander Blume on 17.01.25.
//

import SwiftUI

struct StatusDisplayCompact: View {
    var status: KHAccessStatus

    var body: some View {
        let pv = ProgressView()
            #if os(macOS)
                .scaleEffect(0.5)
            #endif
        let circ = Image(systemName: "circle.fill")
        switch status {
        case .clean:
            circ.foregroundColor(.green)
        case .busy, .queryingParameters:
            pv
        case .couldNotConnect:
            circ.foregroundColor(.red)
        case .speakersFound(let n):
            circ.foregroundColor(n > 0 ? .green : .red)
        case .success:
            Image(systemName: "checkmark").foregroundColor(.green)
        case .otherError:
            Image(systemName: "exclamationmark.circle").foregroundColor(.red)
        }
    }
}

// This could be a function of Status returning String?
struct StatusDisplayText: View {
    var status: KHAccessStatus

    var body: some View {
        switch status {
        case .clean, .success:
            EmptyView()
        case .busy(let s):
            if let s { Text(s) }
        case .queryingParameters:
            Text("Querying...")
        case .couldNotConnect:
            Text("Could not connect")
        case .speakersFound(let n):
            if n == 0 {
                Text("No speakers found")
            } else {
                Text("Discovered \(n) speakers")
            }
        case .otherError(let s):
            Text(s)
        }
    }
}

struct StatusDisplay: View {
    var status: KHAccessStatus

    var body: some View {
        HStack {
            StatusDisplayText(status: status)
            StatusDisplayCompact(status: status)
        }
        .frame(height: 20)
        .frame(minWidth: 33)
    }
}
