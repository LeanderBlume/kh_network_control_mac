//
//  EqChart.swift
//  KH Volume slider
//
//  Created by Leander Blume on 23.06.25.
//

import Charts
import SwiftUI

func magnitudeResponseParametric(
    f: Double,
    boost: Double,
    q: Double,
    f0: Double
) -> Double {
    return boost / (1 + pow(q * (f / f0 - f0 / f), 2))
}

func magnitudeResponseHishelf(f: Double, boost: Double, q: Double, f0: Double) -> Double
{
    return boost / (1 + exp(0.01 * -q * (f - f0)))
}

func magnitudeResponseLoshelf(f: Double, boost: Double, q: Double, f0: Double) -> Double
{
    return boost * (1 - (1 / (1 + exp(0.01 * -q * (f - f0)))))
}

struct EqChart: View {
    var state: KHState

    var body: some View {
        let eqs = state.eqs
        let activeBands = eqs.map { eq in
            eq.enabled.indices.filter { eq.enabled[$0] }
        }

        Chart {
            LinePlot(x: "f", y: "Gain") { f in
                var result = 0.0
                // We should loop over bands before looping over frequencies
                for selectedEq in 0...1 {
                    let eq = eqs[selectedEq]
                    for band in activeBands[selectedEq] {
                        switch eq.type[band] {
                        case "PARAMETRIC":
                            result += magnitudeResponseParametric(
                                f: f,
                                boost: eq.boost[band],
                                q: eq.q[band],
                                f0: eq.frequency[band]
                            )
                        // Not implemented ones
                        case "LOSHELF":
                            result += magnitudeResponseLoshelf(
                                f: f,
                                boost: eq.boost[band],
                                q: eq.q[band],
                                f0: eq.frequency[band]
                            )

                        case "HISHELF":
                            result += magnitudeResponseHishelf(
                                f: f,
                                boost: eq.boost[band],
                                q: eq.q[band],
                                f0: eq.frequency[band]
                            )
                        case "LOWPASS": break
                        case "HIGHPASS": break
                        case "BANDPASS": break
                        case "NOTCH": break
                        case "ALLPASS": break
                        case "HI6DB": break
                        case "LO6DB": break
                        case "INVERSION": break
                        // Above cases are all of them, but need this for switch to be
                        // exhaustive
                        default: break
                        }
                        result += eq.gain[band]
                    }
                }
                return result
            }

            let colors = [Color.yellow, Color.orange]
            ForEach(0..<state.eqs.count, id: \.self) { i in
                let eq = eqs[i]
                ForEach(activeBands[i], id: \.self) { j in
                    PointMark(
                        x: .value("f", eq.frequency[j]),
                        y: .value("Gain", eq.boost[j] - 6)
                    )
                    .foregroundStyle(colors[i % 2])
                    .symbolSize(300)
                    .annotation(position: .overlay) {
                        Text(String(j + 1))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .chartXScale(domain: 20...20000, type: .log)
        .chartYScale(domain: -24...24)
    }
}

#Preview {
    EqChart(state: KHState())
}
