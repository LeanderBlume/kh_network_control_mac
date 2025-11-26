//
//  EqChart.swift
//  KH Volume slider
//
//  Created by Leander Blume on 23.06.25.
//

import SwiftUI
import Charts

func magnitudeResponseParametric(
    f: Double, boost: Double, q: Double, f0: Double
) -> Double {
    return boost * 1 / (1 + pow(q * (f / f0 - f0 / f), 2))
}

struct EqChart: View {
    var khAccess: KHAccess

    var body: some View {
        let eqs = khAccess.eqs
        let activeBands = eqs.map { eq in
            eq.enabled.indices.filter { eq.enabled[$0] }
        }

        Chart {
            LinePlot(x: "f", y: "Gain") { f in
                var result = 0.0
                // We should loop over bands before looping over frequencies
                for selectedEq in 0 ... 1 {
                    let eq = eqs[selectedEq]
                    for band in activeBands[selectedEq] {
                        switch eq.type[band] {
                        case "PARAMETRIC":
                            result += magnitudeResponseParametric(f: f, boost: eq.boost[band], q: eq.q[band], f0: eq.frequency[band])
                        // Not implemented ones
                        case "LOSHELF":
                            let N = 2.0 // order of filter (?)
                            let boost = eq.boost[band]
                            // let q = eq.q[band]
                            // let f0 = eq.frequency[band]
                            let fpow2N = pow(f, 2 * N)
                            let bandResult = sqrt((fpow2N + boost * boost) / (fpow2N + 1))
                            // result += bandResult
                        case "HISHELF": break
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
        }
        .chartXScale(domain: 20 ... 20000, type: .log)
        .chartYScale(domain: -24 ... 24)
    }
}
