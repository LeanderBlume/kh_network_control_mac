//
//  StatusDisplay.swift
//  KH Volume slider
//
//  Created by Leander Blume on 17.01.25.
//

import SwiftUI

struct StatusDisplay: View {
    var status: KHAccess.Status

    var body: some View {
        HStack {
            switch status {
            case .speakersUnavailable:
                Text("Speakers unavailable")
            case .noSpeakersFoundDuringScan:
                Text("No speakers found during scan")
            default:
                EmptyView()

            let pv = ProgressView()
                #if os(macOS)
                    .scaleEffect(0.5)
                #endif
            let circ = Image(systemName: "circle.fill")
            Group {
                switch status {
                case .clean:
                    circ.foregroundColor(.green)
                case .fetching:
                    pv
                case .checkingSpeakerAvailability:
                    pv
                case .speakersUnavailable:
                    circ.foregroundColor(.red)
                case .scanning:
                    pv
                case .noSpeakersFoundDuringScan:
                    circ.foregroundColor(.red)
                }
            }
            .frame(height: 20)
            .frame(minWidth: 33)
            }
        }
    }
}
