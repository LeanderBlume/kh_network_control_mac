//
//  EqPanel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct EqSlidermacOS: View {
    var name: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var logarithmic: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Text(name)
        if logarithmic {
            Slider.withLog2Scale(value: $value, in: range) { editing in
                if !editing {
                    Task {
                        await khAccess.send()
                    }
                }
            }
        } else {
            Slider(value: $value, in: range) { editing in
                if !editing {
                    Task {
                        await khAccess.send()
                    }
                }
            }
        }
        TextField(name, value: $value, format: .number.precision(.fractionLength(1)))
            .frame(width: 80)
            .onSubmit {
                Task {
                    await khAccess.send()
                }
            }
    }
}

struct EqSlideriOS: View {
    var name: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var logarithmic: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        VStack {
            Text(name)

            HStack {
                if logarithmic {
                    Slider.withLog2Scale(value: $value, in: range) { editing in
                        if !editing {
                            Task {
                                await khAccess.send()
                            }
                        }
                    }
                } else {
                    Slider(value: $value, in: range) { editing in
                        if !editing {
                            Task {
                                await khAccess.send()
                            }
                        }
                    }
                }

                TextField(
                    name,
                    value: $value,
                    format: .number.precision(.fractionLength(1))
                )
                .onSubmit {
                    Task {
                        await khAccess.send()
                    }
                }
                /// This doesn't have a return button...
                // .keyboardType(.decimalPad)
                .frame(width: 80)
            }
        }
    }
}

struct EqBandPaneliOS: View {
    @Binding var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        VStack {
            // EQ Type picker
            HStack {
                ZStack(alignment: .leading) {
                    Text("Disable to change")
                        .opacity(enabled ? 1 : 0)
                        .foregroundStyle(.secondary)
                    Text("Type")
                        .opacity(enabled ? 0 : 1)
                }

                Spacer()

                Picker("Type:", selection: $type) {
                    ForEach(Eq.EqType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: type) {
                    Task {
                        await khAccess.send()
                    }
                }
                .disabled(enabled)
            }

            EqSlideriOS(
                name: "Frequency (Hz)",
                value: $frequency,
                range: 10...24000,
                logarithmic: true,
            )
            EqSlideriOS(
                name: "Q",
                value: $q,
                range: 0.1...16,
                logarithmic: true,
            )
            EqSlideriOS(
                name: "Boost (dB)",
                value: $boost,
                range: -99...24,
                logarithmic: false,
            )
            EqSlideriOS(
                name: "Makeup (dB)",
                value: $gain,
                range: -99...24,
                logarithmic: false,
            )
        }
    }
}

struct EqBandPanelmacOS: View {
    @Binding var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        VStack(spacing: 20) {
            // EQ Type picker
            HStack {
                Picker(
                    "Type:",
                    selection: $type
                ) {
                    ForEach(Eq.EqType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: type) {
                    Task {
                        await khAccess.send()
                    }
                }
                .disabled(enabled)

                Spacer()

                if enabled {
                    Text("Disable to change type")
                }
            }

            Grid(alignment: .topLeading) {
                GridRow {
                    EqSlidermacOS(
                        name: "Frequency (Hz)",
                        value: $frequency,
                        range: 10...24000,
                        logarithmic: true,
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Q",
                        value: $q,
                        range: 0.1...16,
                        logarithmic: true,
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Boost (dB)",
                        value: $boost,
                        range: -99...24,
                        logarithmic: false,
                    )

                }
                GridRow {
                    EqSlidermacOS(
                        name: "Makeup (dB)",
                        value: $gain,
                        range: -99...24,
                        logarithmic: false,
                    )
                }
            }
        }

    }
}

struct EqBandPanel: View {
    // Maybe it would be kind of neat if all this stuff was in an EqBand struct...
    @Binding var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double

    var body: some View {
        #if os(macOS)
            EqBandPanelmacOS(
                enabled: $enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain
            )
        #elseif os(iOS)
            EqBandPaneliOS(
                enabled: $enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain
            )
        #endif
    }
}

struct EqPanel: View {
    @Binding var eq: Eq
    @Binding var selectedEqBand: Int
    // @State var position = ScrollPosition
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        let numBands = eq.enabled.count

        VStack(alignment: .center, spacing: 15) {
            GeometryReader { geo in
                ScrollView(.horizontal) {
                    HStack(alignment: .center) {
                        ForEach((0..<numBands), id: \.self) { i in
                            VStack(alignment: .center) {
                                Button(String(i + 1)) {
                                    selectedEqBand = i
                                }
                                .foregroundStyle(
                                    selectedEqBand == i ? .green : .accentColor
                                )

                                Toggle(
                                    "✓",
                                    isOn: $eq.enabled[i]
                                )
                                .toggleStyle(.button)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(minWidth: geo.size.width)
                    .onChange(
                        of: eq.enabled
                    ) {
                        // This also fires when I switch tabs and this stuff hasn't actually
                        // changed. Well, selectedEq changes, so maybe it does change? Not sure.
                        Task {
                            await khAccess.send()
                        }
                    }
                }
                .scrollClipDisabled(true)
            }
            // This is not ideal but the GeometryReader somehow messes things up so
            // this overlaps with stuff below it.
            .frame(height: 70)

            EqBandPanel(
                enabled: $eq.enabled[selectedEqBand],
                type: $eq.type[selectedEqBand],
                frequency: $eq.frequency[selectedEqBand],
                q: $eq.q[selectedEqBand],
                boost: $eq.boost[selectedEqBand],
                gain: $eq.gain[selectedEqBand]
            )
        }
    }
}

struct EqTab: View {
    @State private var selectedEq: Int = 0
    @State var selectedBands: [Int] = [0, 0]
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        @Bindable var khAccess = khAccess

        ScrollView {
            VStack(spacing: 15) {
                EqChart(eqs: khAccess.state.eqs).frame(height: 150)
                
                Picker("", selection: $selectedEq) {
                    Text("post EQ").tag(0)
                    Text("calibration EQ").tag(1)
                }
                .pickerStyle(.segmented)
                
                EqPanel(
                    eq: $khAccess.state.eqs[selectedEq],
                    selectedEqBand: $selectedBands[selectedEq]
                )
            }
        }
    }
}

#Preview {
    EqTab().environment(KHAccess())
}
