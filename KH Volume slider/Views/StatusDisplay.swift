//
//  StatusDisplay.swift
//  KH Volume slider
//
//  Created by Leander Blume on 17.01.25.
//

import SwiftUI

struct StatusDisplay: View {
    var status: KHAccessStatus

    var body: some View {
        let pv = ProgressView()
            #if os(macOS)
                .scaleEffect(0.5)
            #endif
        let circ = Image(systemName: "circle.fill")
        Group {
            switch status {
            case .clean:
                circ.foregroundColor(.green)
            case .busy(let s):
                HStack {
                    if let s {
                        Text(s)
                    }
                    pv
                }
            case .queryingParameters:
                HStack {
                    Text("Querying...")
                    pv
                }
            case .couldNotConnect:
                HStack {
                    Text("Could not connect")
                    circ.foregroundColor(.red)
                }
            case .speakersFound(let n):
                if n == 0 {
                    HStack {
                        Text("No speakers found")
                        circ.foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Text("Discovered \(n) speakers")
                        circ.foregroundColor(.green)
                    }
                }
            case .success:
                // Text("Parameters fetched")
                Image(systemName: "checkmark").foregroundColor(.green)
            case .otherError(let s):
                HStack {
                    Text(s)
                    Image(systemName: "exclamationmark.circle").foregroundColor(.red)
                }
            }
        }
        .frame(height: 20)
        .frame(minWidth: 33)
    }
}
