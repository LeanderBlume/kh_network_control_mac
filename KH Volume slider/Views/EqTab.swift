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
    var khAccess: KHAccess

    var body: some View {
        Text(name)
        if logarithmic {
            Slider.withLog2Scale(value: $value, in: range) { editing in
                if !editing {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
        } else {
            Slider(value: $value, in: range) { editing in
                if !editing {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
        }
        TextField(name, value: $value, format: .number.precision(.fractionLength(1)))
            .frame(width: 80)
            .onSubmit {
                Task {
                    try await khAccess.send()
                }
            }
    }
}

struct EqSlideriOS: View {
    var name: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var logarithmic: Bool
    var khAccess: KHAccess

    var body: some View {
        VStack {
            Text(name)

            HStack {
                if logarithmic {
                    Slider.withLog2Scale(value: $value, in: range) { editing in
                        if !editing {
                            Task {
                                try await khAccess.send()
                            }
                        }
                    }
                } else {
                    Slider(value: $value, in: range) { editing in
                        if !editing {
                            Task {
                                try await khAccess.send()
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
                        try await khAccess.send()
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
    var khAccess: KHAccess
    @Binding var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double

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
                        try await khAccess.send()
                    }
                }
                .disabled(enabled)
            }

            EqSlideriOS(
                name: "Frequency (Hz)",
                value: $frequency,
                range: 10...24000,
                logarithmic: true,
                khAccess: khAccess
            )
            EqSlideriOS(
                name: "Q",
                value: $q,
                range: 0.1...16,
                logarithmic: true,
                khAccess: khAccess
            )
            EqSlideriOS(
                name: "Boost (dB)",
                value: $boost,
                range: -99...24,
                logarithmic: false,
                khAccess: khAccess
            )
            EqSlideriOS(
                name: "Makeup (dB)",
                value: $gain,
                range: -99...24,
                logarithmic: false,
                khAccess: khAccess
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
    var khAccess: KHAccess

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
                        try await khAccess.send()
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
                        khAccess: khAccess
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Q",
                        value: $q,
                        range: 0.1...16,
                        logarithmic: true,
                        khAccess: khAccess
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Boost (dB)",
                        value: $boost,
                        range: -99...24,
                        logarithmic: false,
                        khAccess: khAccess
                    )

                }
                GridRow {
                    EqSlidermacOS(
                        name: "Makeup (dB)",
                        value: $gain,
                        range: -99...24,
                        logarithmic: false,
                        khAccess: khAccess
                    )
                }
            }
        }

    }
}

struct EqBandPanel: View {
    @Binding var enabled: Bool
    @Binding var type: String
    @Binding var frequency: Double
    @Binding var q: Double
    @Binding var boost: Double
    @Binding var gain: Double
    var khAccess: KHAccess

    var body: some View {
        #if os(macOS)
            EqBandPanelmacOS(
                enabled: $enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain,
                khAccess: khAccess
            )
        #elseif os(iOS)
            EqBandPaneliOS(
                enabled: $enabled,
                type: $type,
                frequency: $frequency,
                q: $q,
                boost: $boost,
                gain: $gain,
                khAccess: khAccess
            )
        #endif
    }
}

struct EqPanel: View {
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    @Binding var selectedEqBand: Int
    // @State var position = ScrollPosition

    var body: some View {
        let numBands = khAccess.state.eqs[selectedEq].enabled.count

        VStack(alignment: .center, spacing: 20) {
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
                                    isOn: $khAccess.state.eqs[selectedEq].enabled[i]
                                )
                                .toggleStyle(.button)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(minWidth: geo.size.width)
                    .onChange(
                        of: khAccess.state.eqs[selectedEq].enabled
                    ) {
                        // This also fires when I switch tabs and this stuff hasn't actually
                        // changed. Well, selectedEq changes, so maybe it does change? Not sure.
                        Task {
                            try await khAccess.send()
                        }
                    }
                }
                .scrollClipDisabled(true)
            }
            // This is not ideal but the GeometryReader somehow messes things up so
            // this overlaps with stuff below it.
            .frame(minHeight: 70)

            EqBandPanel(
                enabled: $khAccess.state.eqs[selectedEq].enabled[selectedEqBand],
                type: $khAccess.state.eqs[selectedEq].type[selectedEqBand],
                frequency: $khAccess.state.eqs[selectedEq].frequency[selectedEqBand],
                q: $khAccess.state.eqs[selectedEq].q[selectedEqBand],
                boost: $khAccess.state.eqs[selectedEq].boost[selectedEqBand],
                gain: $khAccess.state.eqs[selectedEq].gain[selectedEqBand],
                khAccess: khAccess
            )
        }
    }
}

struct EqTab: View {
    var khAccess: KHAccess
    @State private var selectedEq: Int = 0
    @State var selectedBands: [Int] = [0, 0]

    var body: some View {
        ScrollView {
            EqChart(state: khAccess.state).frame(height: 150)

            VStack(spacing: 20) {
                Picker("", selection: $selectedEq) {
                    Text("post EQ").tag(0)
                    Text("calibration EQ").tag(1)
                }
                .pickerStyle(.segmented)

                EqPanel(
                    khAccess: khAccess,
                    selectedEq: selectedEq,
                    selectedEqBand: $selectedBands[selectedEq]
                )
            }
        }
    }
}

#Preview {
    let khAccess = KHAccess()
    EqTab(khAccess: khAccess)
}
