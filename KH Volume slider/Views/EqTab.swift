//
//  EqPanel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

private struct EqTypePicker: View {
    var bandEnabled: Bool
    @Binding var type: String

    @ViewBuilder
    var ViewiOS: some View {
        ZStack(alignment: .leading) {
            Text("Disable to change EQ Type")
                .opacity(bandEnabled ? 1 : 0)
                .foregroundStyle(.secondary)
            Picker("Type:", selection: $type) {
                ForEach(EqType.allCases) { type in
                    Text(type.rawValue).tag(type.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(bandEnabled)
            .opacity(bandEnabled ? 0 : 1)
        }
    }

    @ViewBuilder
    var ViewMacOS: some View {
        Text("Type")

        HStack {
            Picker("Type:", selection: $type) {
                ForEach(EqType.allCases) { type in
                    Text(type.rawValue).tag(type.rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(bandEnabled)
            .labelsHidden()

            if bandEnabled {
                Text("Disable band to change type")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        #if os(iOS)
            ViewiOS
        #elseif os(macOS)
            ViewMacOS
        #endif
    }
}

private struct EqBandPanel: View {
    var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private struct SliderParams: Identifiable {
        var name: String
        var value: Binding<Double>
        var range: ClosedRange<Double>
        var logarithmic: Bool

        var id: String { name }
    }

    private var sliders: [SliderParams] {
        [
            .init(
                name: "Frequency (Hz)",
                value: $frequency,
                range: 10...24000,
                logarithmic: true
            ),
            .init(
                name: "Q",
                value: $q,
                range: 0.1...16,
                logarithmic: true
            ),
            .init(
                name: "Boost (dB)",
                value: $boost,
                range: -99...24,
                logarithmic: false
            ),
            .init(
                name: "Makeup (dB)",
                value: $gain,
                range: -99...24,
                logarithmic: false
            ),
        ]
    }

    @ViewBuilder
    var bodyiOS: some View {
        EqTypePicker(bandEnabled: enabled, type: $type)
            .onChange(of: type) { Task { await khAccess.send() } }

        Grid(alignment: .leading) {
            ForEach(sliders.indices, id: \.self) { i in
                LabeledSliderTextField(
                    name: sliders[i].name,
                    value: sliders[i].value,
                    range: sliders[i].range,
                    logarithmic: sliders[i].logarithmic,
                )
                if i + 1 != sliders.count {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    var bodymacOS: some View {
        Grid(alignment: .topLeading) {
            GridRow {
                EqTypePicker(bandEnabled: enabled, type: $type)
                    .onChange(of: type) { Task { await khAccess.send() } }
                    .padding(.bottom, 5)
            }
            ForEach(sliders.indices, id: \.self) { i in
                GridRow {
                    LabeledSliderTextField(
                        name: sliders[i].name,
                        value: sliders[i].value,
                        range: sliders[i].range,
                        logarithmic: sliders[i].logarithmic,
                    )
                }
            }
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}

private struct SingleBandPickerButton: View {
    var band: Int
    @Binding var selectedEqBand: Int
    @Binding var eq: Eq

    var body: some View {
        let active = band == selectedEqBand
        VStack(alignment: .center, spacing: 27) {
            Button(String(band + 1)) { selectedEqBand = band }
                .foregroundStyle(active ? .green : .secondary)
                // .font(active ? .title3 : .caption)

            Toggle("✓", isOn: $eq.enabled[band])
                .toggleStyle(.switch)
                .labelsHidden()
                .rotationEffect(Angle(degrees: -90))
        }
        .frame(width: 35) // , height: 80)
        // .background( band == selectedEqBand ? .red : .gray)
    }
}

private struct BandPicker: View {
    var numBands: Int
    @Binding var selectedEqBand: Int
    @Binding var eq: Eq

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(alignment: .center) {
                    ForEach((0..<numBands), id: \.self) { i in
                        SingleBandPickerButton(
                            band: i,
                            selectedEqBand: $selectedEqBand,
                            eq: $eq
                        )
                        // .padding(.bottom, 10)
                    }
                }
                .frame(minWidth: geo.size.width)
                // .frame(height: 90)
            }
            .scrollClipDisabled(true)
        }
        // This is not ideal but the GeometryReader somehow messes things up so
        // this overlaps with stuff below it.
        .frame(height: 90)
    }
}

private struct EqPanel: View {
    @Binding var eq: Eq
    @Binding var selectedEqBand: Int
    // @State var position = ScrollPosition
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        BandPicker(numBands: eq.enabled.count, selectedEqBand: $selectedEqBand, eq: $eq)
            .onChange(of: eq.enabled) {
                Task { await khAccess.send() }
            }

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

    var body: some View {
        @Bindable var khAccess = khAccess

        EqChart(eqs: khAccess.state.eqs).frame(height: 150)

        Picker("", selection: $selectedEq) {
            Text("post EQ")
                .tag(0)
            Text("calibration EQ")
                .tag(1)
        }
        .pickerStyle(.segmented)

        EqPanel(
            eq: $khAccess.state.eqs[selectedEq],
            selectedEqBand: $selectedBands[selectedEq]
        )
    }
}

#Preview {
    EqTab().environment(KHAccess())
}
