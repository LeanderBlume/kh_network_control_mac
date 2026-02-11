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
        eqs.indices.reduce(0) { partial, i in
            partial
                + activeBands[i].reduce(0) { partial, next in
                    partial + eqs[i].magnitudeResponse(for: next)(f) + eqs[i].gain[next]
                }
        }
    }
}

struct EqChart: View {
    var eqs: [Eq]

    var body: some View {
        Chart {
            LinePlot(x: "f", y: "Gain", function: magnitudeResponse(eqs: eqs))

            let colors = [Color.yellow, Color.orange]
            ForEach(eqs.indices, id: \.self) { i in
                let eq = eqs[i]
                ForEach(eq.enabled.indices, id: \.self) { j in
                    let x = eq.frequency[j]
                    let y = eq.boost[j]
                    let sign = y.sign == .minus ? -1.0 : 1.0
                    PointMark(
                        x: .value("f", x),
                        y: .value("Gain", y + sign * 2.0)
                    )
                    .symbolSize(0)
                    .annotation(position: y.sign == .minus ? .bottom : .top) {
                        Image(systemName: "\(j + 1).circle")
                            .foregroundStyle(colors[i])
                            .opacity(eq.enabled[j] ? 1 : 0)
                            .scaleEffect(1.5)
                    }
                    .opacity(eq.enabled[j] ? 1 : 0)
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
