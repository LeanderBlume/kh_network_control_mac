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
    var logarithmic: Bool = false
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
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
}

struct EqSlideriOS: View {
    var name: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var logarithmic: Bool = false
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
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
}

struct EqTypePickeriOS: View {
    var enabled: Bool
    @Binding var type: String

    var body: some View {
        ZStack(alignment: .leading) {
            Text("Disable to change EQ Type")
                .opacity(enabled ? 1 : 0)
                .foregroundStyle(.secondary)
            Picker("Type:", selection: $type) {
                ForEach(Eq.EqType.allCases) { type in
                    Text(type.rawValue).tag(type.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(enabled)
            .opacity(enabled ? 0 : 1)
        }
    }
}

struct EqBandPaneliOS: View {
    var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        EqTypePickeriOS(enabled: enabled, type: $type)
            .onChange(of: type) { Task { await khAccess.send() } }

        Grid(alignment: .leading) {
            EqSlideriOS(
                name: "Frequency (Hz)",
                value: $frequency,
                range: 10...24000,
                logarithmic: true
            )
            Divider()
            EqSlideriOS(
                name: "Q",
                value: $q,
                range: 0.1...16,
                logarithmic: true
            )
            Divider()
            EqSlideriOS(
                name: "Boost (dB)",
                value: $boost,
                range: -99...24,
                logarithmic: false,
            )
            Divider()
            EqSlideriOS(
                name: "Makeup (dB)",
                value: $gain,
                range: -99...24,
                logarithmic: false,
            )
        }
    }
}

struct EqTypePickermacOS: View {
    var enabled: Bool
    @Binding var type: String

    var body: some View {
        Text("Type")

        if enabled {
            Text("Disable to change type")
                .foregroundStyle(.secondary)
        } else {
            Picker("Type:", selection: $type) {
                ForEach(Eq.EqType.allCases) { type in
                    Text(type.rawValue).tag(type.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(enabled)
            .labelsHidden()
        }
    }
}

struct EqBandPanelmacOS: View {
    var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Grid(alignment: .topLeading) {
            GridRow {
                EqTypePickermacOS(enabled: enabled, type: $type)
                    .onChange(of: type) { Task { await khAccess.send() } }
                    .padding(.bottom, 5)
            }
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

struct EqBandPanel: View {
    // Maybe it would be kind of neat if all this stuff was in an EqBand struct...
    var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double

    var body: some View {
        #if os(macOS)
            EqBandPanelmacOS(
                enabled: enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain
            )
        #elseif os(iOS)
            EqBandPaneliOS(
                enabled: enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain
            )
        #endif
    }
}

struct SingleBandPickerButton: View {
    var band: Int
    @Binding var selectedEqBand: Int
    @Binding var eq: Eq

    var body: some View {
        VStack(alignment: .center) {
            Button(String(band + 1)) { selectedEqBand = band }
                .foregroundStyle(selectedEqBand == band ? .green : .accentColor)

            Toggle("✓", isOn: $eq.enabled[band]).toggleStyle(.button)
        }
    }
}

struct EqPanel: View {
    @Binding var eq: Eq
    @Binding var selectedEqBand: Int
    // @State var position = ScrollPosition
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        let numBands = eq.enabled.count

        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(alignment: .center) {
                    ForEach((0..<numBands), id: \.self) { i in
                        SingleBandPickerButton(
                            band: i,
                            selectedEqBand: $selectedEqBand,
                            eq: $eq
                        )
                        .padding(.bottom, 10)
                    }
                }
                .frame(minWidth: geo.size.width)
                // This also fires when I switch tabs and this stuff hasn't actually
                // changed. Well, selectedEq changes, so maybe it does change? Not sure.
                .onChange(of: eq.enabled) { Task { await khAccess.send() } }
            }
            .scrollClipDisabled(true)
        }
        // This is not ideal but the GeometryReader somehow messes things up so
        // this overlaps with stuff below it.
        .frame(height: 70)

        EqBandPanel(
            enabled: eq.enabled[selectedEqBand],
            type: $eq.type[selectedEqBand],
            frequency: $eq.frequency[selectedEqBand],
            q: $eq.q[selectedEqBand],
            boost: $eq.boost[selectedEqBand],
            gain: $eq.gain[selectedEqBand]
        )
    }
}

struct EqTab: View {
    @State private var selectedEq: Int = 0
    @State var selectedBands: [Int] = [0, 0]
    @Environment(KHAccess.self) private var khAccess: KHAccess
    // @FocusState private var textFieldFocused: Bool

    var body: some View {
        @Bindable var khAccess = khAccess

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
        // .focused($textFieldFocused)  // THIS WORKS???
        // .navigationTitle(Text("Equalizer"))
        /*
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    Task { await khAccess.send() }
                    textFieldFocused = false
                }
            }
        }
         */
    }
}

#Preview {
    EqTab().environment(KHAccess())
}
