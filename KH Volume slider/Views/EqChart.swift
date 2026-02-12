//
//  EqChart.swift
//  KH Volume slider
//
//  Created by Leander Blume on 23.06.25.
//

import Charts
import SwiftUI

private func magnitudeResponse(eqs: [Eq]) -> (@Sendable (Double) -> Double) {
    let activeBands = eqs.map { eq in
        eq.enabled.indices.filter { eq.enabled[$0] }
    }
    return { f in
        eqs.indices.flatMap { i in
            activeBands[i].map { j in
                eqs[i].magnitudeResponse(for: j)(f) + eqs[i].gain[j]
            }
        }.reduce(0, +)
    }
}

struct EqChart: View {
    var eqs: [Eq]

    var body: some View {
        let mr = magnitudeResponse(eqs: eqs)
        Chart {
            LinePlot(x: "f", y: "Gain", function: mr)

            let colors = [Color.yellow, Color.orange]
            ForEach(eqs.indices, id: \.self) { i in
                let eq = eqs[i]
                ForEach(eq.enabled.indices, id: \.self) { j in
                    let x = eq.frequency[j]
                    let y = mr(x)
                    let sign = y.sign == .minus ? -1.0 : 1.0
                    PointMark(x: .value("f", x), y: .value("Gain", y))
                        .symbol {
                            Image(systemName: "\(j + 1).circle.fill")
                                .foregroundStyle(colors[i])
                                .opacity(eq.enabled[j] ? 1 : 0)
                                .transformEffect(
                                    CGAffineTransform(translationX: 0, y: sign * -13.0)
                                )
                                #if os(macOS)
                                    .scaleEffect(1.5)
                                #endif
                        }
                }
            }
        }
        .chartXScale(domain: 20...20000, type: .log)
        .chartYScale(domain: -24...24)
    }
}

#Preview {
    EqChart(eqs: [Eq(numBands: 10)])
}
