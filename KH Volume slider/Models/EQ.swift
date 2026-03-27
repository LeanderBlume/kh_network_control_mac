//
//  EQ.swift
//  KH Volume slider
//
//  Created by Leander Blume on 26.03.26.
//

import ComplexModule
import Foundation

enum EqType: String, CaseIterable, Identifiable {
    case parametric = "PARAMETRIC"
    case hishelf = "HISHELF"
    case loshelf = "LOSHELF"
    case highpass = "HIGHPASS"
    case lowpass = "LOWPASS"
    case hi6db = "HI6DB"
    case lo6db = "LO6DB"
    case bandpass = "BANDPASS"
    case notch = "NOTCH"
    case allpass = "ALLPASS"
    case inversion = "INVERSION"

    var id: String { self.rawValue }

    private typealias TransferFunc = ((Complex<Double>) -> Complex<Double>)

    private static func toDecibel(_ x: Double) -> Double { 20 * log10(x) }
    private static func fromDecibel(_ x: Double) -> Double { pow(10, x / 20) }

    private static func parametricTransfer(f0: Double, boost: Double, q: Double)
        -> TransferFunc
    {
        let F = Complex<Double>(f0)
        let B = Complex<Double>(fromDecibel(boost))
        let Q = Complex<Double>(q)
        return { s in
            let numer = s * s + B * F / Q * s + F * F
            let denom = s * s + F / Q * s + F * F
            return numer / denom
        }
    }

    private static func highshelfTransfer(f0: Double, boost: Double, q: Double)
        -> TransferFunc
    {
        let F = Complex<Double>(f0)
        let B = Complex<Double>(fromDecibel(boost / 2))
        let Q = Complex<Double>(q)
        return { s in
            let numer = B * s * s + Complex.sqrt(B) / Q * F * s + F * F
            let denom = s * s + Complex.sqrt(B) / Q * F * s + B * F * F
            return B * numer / denom
        }
    }

    private static func lowshelfTransfer(f0: Double, boost: Double, q: Double)
        -> TransferFunc
    {
        let F = Complex<Double>(f0)
        let B = Complex<Double>(fromDecibel(boost / 2))
        let Q = Complex<Double>(q)
        return { s in
            let numer = s * s + Complex.sqrt(B) / Q * F * s + B * F * F
            let denom = B * s * s + Complex.sqrt(B) / Q * F * s + F * F
            return B * numer / denom
        }
    }

    private static func highpassTransfer(f0: Double, q: Double) -> TransferFunc {
        let F = Complex<Double>(f0)
        let Q = Complex<Double>(q)
        return { s in (s * s) / (s * s + F / Q * s + F * F) }
    }

    private static func lowpassTransfer(f0: Double, q: Double) -> TransferFunc {
        let F = Complex<Double>(f0)
        let Q = Complex<Double>(q)
        return { s in (F * F) / (s * s + F / Q * s + F * F) }
    }

    private static func hi6dbTransfer(f0: Double) -> TransferFunc {
        let F = Complex<Double>(f0)
        return { s in (s / F) / (Complex<Double>(1) + s / F) }
    }

    private static func lo6dbTransfer(f0: Double) -> TransferFunc {
        let F = Complex<Double>(f0)
        return { s in 1 / (Complex<Double>(1) + s / F) }
    }

    private static func bandpassTransfer(f0: Double, q: Double) -> TransferFunc {
        // This is 6db/octave, not sure if that's right.
        let F = Complex<Double>(f0)
        let Q = Complex<Double>(q)
        return { s in (F / Q * s) / (s * s + F / Q * s + F * F) }
    }

    private static func notchTransfer(f0: Double, q: Double) -> TransferFunc {
        let F = Complex<Double>(f0)
        let Q = Complex<Double>(q)
        return { s in (s * s + F * F) / (s * s + F / Q * s + F * F) }
    }

    private func transferFunction(f0: Double, boost: Double, q: Double) -> TransferFunc
    {
        switch self {
        case .parametric:
            Self.parametricTransfer(f0: f0, boost: boost, q: q)
        case .hishelf:
            Self.highshelfTransfer(f0: f0, boost: boost, q: q)
        case .loshelf:
            Self.lowshelfTransfer(f0: f0, boost: boost, q: q)
        case .highpass:
            Self.highpassTransfer(f0: f0, q: q)
        case .lowpass:
            Self.lowpassTransfer(f0: f0, q: q)
        case .hi6db:
            Self.hi6dbTransfer(f0: f0)
        case .lo6db:
            Self.lo6dbTransfer(f0: f0)
        case .bandpass:
            Self.bandpassTransfer(f0: f0, q: q)
        case .notch:
            Self.notchTransfer(f0: f0, q: q)
        case .allpass, .inversion:
            { s in Complex<Double>(1) }
        }
    }

    func magnitudeResponse() -> ((Double, Double, Double, Double) -> Double) {
        { f, boost, q, f0 in
            let H = transferFunction(f0: f0, boost: boost, q: q)
            let f_ = Complex<Double>(imaginary: f)
            return Self.toDecibel(H(f_).length)
        }
    }
}

struct Eq: Codable, Equatable {
    var desc: String = ""
    var boost: [Double]
    var enabled: [Bool]
    var frequency: [Double]
    var gain: [Double]
    var q: [Double]
    var type: [String]

    var numBands: Int? {
        let counts = Set([
            boost.count, enabled.count, frequency.count, gain.count, q.count,
            type.count,
        ])
        guard counts.count == 1 else { return nil }
        return counts.first!
    }

    init(numBands: Int) {
        boost = Array(repeating: 0.0, count: numBands)
        enabled = Array(repeating: false, count: numBands)
        frequency = Array(repeating: 100.0, count: numBands)
        gain = Array(repeating: 0.0, count: numBands)
        q = Array(repeating: 0.7, count: numBands)
        type = Array(repeating: EqType.parametric.rawValue, count: numBands)
    }

    func magnitudeResponse(for band: Int) -> ((Double) -> Double) {
        let mr = EqType(rawValue: type[band])!.magnitudeResponse()
        return { f in mr(f, boost[band], q[band], frequency[band]) }
    }
}
