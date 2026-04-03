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
    var eqIndex: Int
    var eqName: String
    var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    var sendCallback: (SSCParameter) async -> Void
    @FocusState.Binding var textFieldFocused: SSCParameter?

    private struct SliderParams: Identifiable {
        var name: String
        var value: Binding<Double>
        var range: ClosedRange<Double>
        var logarithmic: Bool
        var eqParameter: EQParameter

        var id: String { name }
    }

    private var sliders: [SliderParams] {
        [
            .init(
                name: "Frequency (Hz)",
                value: $frequency,
                range: 10...24000,
                logarithmic: true,
                eqParameter: .frequency
            ),
            .init(
                name: "Q",
                value: $q,
                range: 0.1...16,
                logarithmic: true,
                eqParameter: .q,
            ),
            .init(
                name: "Boost (dB)",
                value: $boost,
                range: -99...24,
                logarithmic: false,
                eqParameter: .boost,
            ),
            .init(
                name: "Makeup (dB)",
                value: $gain,
                range: -99...24,
                logarithmic: false,
                eqParameter: .gain
            ),
        ]
    }

    var bodyiOS: some View {
        Grid(alignment: .leading) {
            EqTypePicker(bandEnabled: enabled, type: $type)
                .onChange(of: type) {
                    Task { await sendCallback(.eq(eqIndex, eqName, .type)) }
                }
                .padding(.vertical, 5)

            Divider()

            ForEach(sliders.indices, id: \.self) { i in
                LabeledSliderTextField(
                    name: sliders[i].name,
                    value: sliders[i].value,
                    range: sliders[i].range,
                    logarithmic: sliders[i].logarithmic,
                    sendCallback: {
                        await sendCallback(.eq(eqIndex, eqName, sliders[i].eqParameter))
                    }
                )
                .focused(
                    $textFieldFocused,
                    equals: .eq(eqIndex, eqName, sliders[i].eqParameter)
                )

                if i + 1 != sliders.count {
                    Divider()
                }
            }
        }
    }

    var bodymacOS: some View {
        Grid(alignment: .topLeading) {
            GridRow {
                EqTypePicker(bandEnabled: enabled, type: $type)
                    .onChange(of: type) {
                        Task { await sendCallback(.eq(eqIndex, eqName, .type)) }
                    }
                    .padding(.vertical, 5)
            }
            ForEach(sliders.indices, id: \.self) { i in
                GridRow {
                    LabeledSliderTextField(
                        name: sliders[i].name,
                        value: sliders[i].value,
                        range: sliders[i].range,
                        logarithmic: sliders[i].logarithmic,
                        sendCallback: {
                            await sendCallback(
                                .eq(eqIndex, eqName, sliders[i].eqParameter)
                            )
                        }
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
    @Binding var enabled: [Bool]

    var body: some View {
        let active = band == selectedEqBand
        VStack(alignment: .center, spacing: 27) {
            /// Either this or toggleStyle .button in the menu bar crashes the app on macOS 15.
            /*
            Button(String(band + 1)) { selectedEqBand = band }
                .foregroundStyle(active ? .green : .secondary)
                // .font(active ? .title3 : .caption)
             */
            if active {
                Button(String(band + 1)) { selectedEqBand = band }
                    .foregroundStyle(.accent)
            } else {
                Button(String(band + 1)) { selectedEqBand = band }
                    .foregroundStyle(.secondary)
            }
            // .font(active ? .title3 : .caption)

            Toggle("✓", isOn: $enabled[band])
                .toggleStyle(.switch)
                .labelsHidden()
                .rotationEffect(Angle(degrees: -90))
        }
        .frame(width: 35)
        .padding(.bottom, 20)
        // .background( band == selectedEqBand ? .red : .gray)
    }
}

private struct BandPicker: View {
    var numBands: Int
    @Binding var selectedEqBand: Int
    @Binding var enabled: [Bool]

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(alignment: .bottom) {
                    ForEach((0..<numBands), id: \.self) { i in
                        SingleBandPickerButton(
                            band: i,
                            selectedEqBand: $selectedEqBand,
                            enabled: $enabled
                        )
                    }
                }
                .frame(minWidth: geo.size.width)
            }
            .scrollClipDisabled(true)
        }
        .frame(height: 95)
        // This is not ideal but the GeometryReader somehow messes things up so
        // this overlaps with stuff below it.
    }
}

private struct EqPanel: View {
    var eqIndex: Int
    var eqName: String
    @Binding var eq: Eq
    @Binding var selectedEqBand: Int
    // @State var position = ScrollPosition
    var sendCallback: (SSCParameter) async -> Void
    @FocusState.Binding var textFieldFocused: SSCParameter?

    var body: some View {
        VStack {
            BandPicker(
                numBands: eq.numBands ?? 0,
                selectedEqBand: $selectedEqBand,
                enabled: $eq.enabled
            )
            .onChange(of: eq.enabled) {
                Task { await sendCallback(.eq(eqIndex, eqName, .enabled)) }
            }
            #if os(iOS)
                .padding(.bottom, 7)
            #elseif os(macOS)
                .padding(.bottom, 15)
            #endif

            #if os(iOS)
                Divider()
            #endif
            
            ZStack {
                ForEach(0..<(eq.numBands ?? -1), id: \.self) { i in
                    EqBandPanel(
                        eqIndex: eqIndex,
                        eqName: eqName,
                        enabled: eq.enabled[i],
                        type: $eq.type[i],
                        frequency: $eq.frequency[i],
                        q: $eq.q[i],
                        boost: $eq.boost[i],
                        gain: $eq.gain[i],
                        sendCallback: sendCallback,
                        textFieldFocused: $textFieldFocused
                    )
                    .opacity(i == selectedEqBand ? 1 : 0)
                }
            }
        }
    }
}

struct EqTab: View {
    @Binding var eqs: [Eq]
    var sendCallback: (SSCParameter) async -> Void
    var deviceModel: DeviceModel
    @FocusState.Binding var textFieldFocused: SSCParameter?

    @State private var selectedEq: Int = 0
    @State var selectedBands: [Int] = [0, 0]

    var body: some View {
        EqChart(eqs: eqs).frame(height: 150)

        Picker("", selection: $selectedEq) {
            Text("post EQ")
                .tag(0)
            Text("calibration EQ")
                .tag(1)
        }
        .pickerStyle(.segmented)

        ZStack {
            ForEach(eqs.indices, id: \.self) { i in
                EqPanel(
                    eqIndex: i,
                    eqName: deviceModel.eqName(i),
                    eq: $eqs[i],
                    selectedEqBand: $selectedBands[i],
                    sendCallback: sendCallback,
                    textFieldFocused: $textFieldFocused
                )
                .opacity(i == selectedEq ? 1 : 0)
            }
        }
    }
}
