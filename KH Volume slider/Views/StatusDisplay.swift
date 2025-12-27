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
                HStack {
                    Text("Fetching...")
                    pv
                }
            case .checkingSpeakerAvailability:
                HStack {
                    Text("Connecting...")
                    pv
                }
            case .scanning:
                HStack {
                    Text("Scanning...")
                    pv
                }
            case .queryingParameters:
                HStack {
                    Text("Querying...")
                    pv
                }
            case .speakersUnavailable:
                HStack {
                    Text("Speakers unavailable")
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
            }
        }
        .frame(height: 20)
        .frame(minWidth: 33)
    }
}
