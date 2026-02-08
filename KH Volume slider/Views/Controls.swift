//
//  LogSlider.swift
//  KH Volume slider
//
//  Created by Leander Blume on 16.01.25.
//

import SwiftUI

// Stolen from https://gist.github.com/prachigauriar/c508799bad359c3aa271ccc0865de231
extension Binding where Value == Double {
    /// Returns a new version of the binding that scales the value logarithmically using the specified base. That is,
    /// when getting the value, `log_b(value)` is returned; when setting it, the new value is `pow(base, newValue)`.
    ///
    /// - Parameter base: The base to use.
    func logarithmic(base: Double = 2) -> Binding<Double> {
        Binding(
            get: {
                log10(self.wrappedValue) / log10(base)
            },
            set: { (newValue) in
                self.wrappedValue = pow(base, newValue)
            }
        )
    }
}

extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    /// Creates a new `Slider` with a base-10 logarithmic scale.
    ///
    /// ## Example
    ///
    ///     @State private var frequency = 1.0
    ///
    ///     var body: some View {
    ///         Slider.withLog10Scale(value: $frequency, in: 1 ... 100)
    ///     }
    ///
    /// - Parameters:
    ///   - value: A binding to the unscaled value.
    ///   - range: The unscaled range of values.
    ///   - onEditingChanged: Documentation forthcoming.
    static func withLog2Scale(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) -> Slider {
        return self.init(
            value: value.logarithmic(),
            in: log2(range.lowerBound)...log2(range.upperBound),
            onEditingChanged: onEditingChanged
        )
    }
}

struct LabeledSliderTextField: View {
    var name: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var logarithmic: Bool = false
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ViewBuilder
    var bodyiOS: some View {
        GridRow {
            Text(name + ":")

            TextField(
                name,
                value: $value,
                format: .number.precision(.fractionLength(1))
            )
            .onSubmit { Task { await khAccess.send() } }
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        }

        if logarithmic {
            Slider.withLog2Scale(value: $value, in: range) { editing in
                if !editing { Task { await khAccess.send() } }
            }
        } else {
            Slider(value: $value, in: range) { editing in
                if !editing { Task { await khAccess.send() } }
            }
        }
    }

    @ViewBuilder
    var bodyMacOS: some View {
        Text(name)
        if logarithmic {
            Slider.withLog2Scale(value: $value, in: range) { editing in
                if !editing { Task { await khAccess.send() } }
            }
        } else {
            Slider(value: $value, in: range) { editing in
                if !editing { Task { await khAccess.send() } }
            }
        }
        TextField(name, value: $value, format: .number.precision(.fractionLength(1)))
            .frame(width: 80)
            .onSubmit { Task { await khAccess.send() } }
            .labelsHidden()
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodyMacOS
        #endif
    }
}
