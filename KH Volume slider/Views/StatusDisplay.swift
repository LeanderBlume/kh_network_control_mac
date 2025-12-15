//
//  StatusDisplay.swift
//  KH Volume slider
//
//  Created by Leander Blume on 17.01.25.
//

import SwiftUI

struct StatusDisplay: View {
    var status: KHAccess.Status
    
    @State private var showCheckmark: Bool = false
    
    private func playAnimation() async throws {
        showCheckmark = true
        try await Task.sleep(nanoseconds: 1000_000_000)
        showCheckmark = false
    }

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
                    Text("FETCHING")
                case .fetchingSuccess:
                    Group {
                        if showCheckmark {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        } else {
                            circ.foregroundColor(.yellow)
                        }
                    }
                    .onAppear {
                        Task {
                            try await playAnimation()
                        }
                    }
                case .checkingSpeakerAvailability:
                    pv
                    Text("CHECKING AVAILABILITY")
                case .speakersAvailable:
                    EmptyView()  // TODO
                case .speakersUnavailable:
                    circ.foregroundColor(.red)
                case .scanning:
                    pv
                    Text("SCANNING")
                case .speakersFound:
                    EmptyView()  // TODO
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
