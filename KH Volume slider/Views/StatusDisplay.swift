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
            case .clean, .speakersAvailable:
                circ.foregroundColor(.green)
            case .fetching:
                Text("Fetching...")
                pv
            case .checkingSpeakerAvailability:
                Text("Connecting...")
                pv
            case .scanning:
                Text("Scanning...")
                pv
            case .speakersUnavailable:
                Text("Speakers unavailable")
                circ.foregroundColor(.red)
            case .speakersFound(let n):
                if n == 0 {
                    Text("No speakers discovered")
                    circ.foregroundColor(.red)
                } else {
                    Text("Discovered \(n) speakers")
                    circ.foregroundColor(.green)
                }
            case .fetchingSuccess:
                Text("Parameters fetched")
                Image(systemName: "checkmark").foregroundColor(.green)
            case .queryingParameters:
                Text("Querying...")
            }
        }
        .frame(height: 20)
        .frame(minWidth: 33)
    }
}
