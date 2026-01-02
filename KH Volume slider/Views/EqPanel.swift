//
//  EqPanel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct EqSlidermacOS: View {
    var binding: Binding<[Double]>
    var name: String
    var unit: String?
    var range: ClosedRange<Double>
    var logarithmic: Bool
    var selectedEqBand: Int
    var khAccess: KHAccess

    var body: some View {
        let unitString: String = unit != nil ? " (\(unit!))" : ""

        Text(name + unitString)
        if logarithmic {
            Slider.withLog2Scale(value: binding[selectedEqBand], in: range) {
                editing in
                if !editing {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
        } else {
            Slider(value: binding[selectedEqBand], in: range) { editing in
                if !editing {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
        }
        TextField(
            name,
            value: binding[selectedEqBand],
            format: .number.precision(.fractionLength(1))
        )
        .frame(width: 80)
        .onSubmit {
            Task {
                try await khAccess.send()
            }
        }
    }
}

struct EqSlideriOS: View {
    var binding: Binding<[Double]>
    var name: String
    var unit: String?
    var range: ClosedRange<Double>
    var logarithmic: Bool
    var selectedEqBand: Int
    var khAccess: KHAccess

    var body: some View {
        let unitString: String = unit != nil ? " (\(unit!))" : ""

        VStack {
            Text(name + unitString)

            HStack {
                if logarithmic {
                    Slider.withLog2Scale(value: binding[selectedEqBand], in: range) {
                        editing in
                        if !editing {
                            Task {
                                try await khAccess.send()
                            }
                        }
                    }
                } else {
                    Slider(value: binding[selectedEqBand], in: range) { editing in
                        if !editing {
                            Task {
                                try await khAccess.send()
                            }
                        }
                    }
                }

                TextField(
                    name,
                    value: binding[selectedEqBand],
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
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    var selectedEqBand: Int

    var body: some View {
        VStack {
            // EQ Type picker
            HStack {
                ZStack(alignment: .leading) {
                    Text("Disable to change")
                        .opacity(
                            khAccess.state.eqs[selectedEq].enabled[selectedEqBand]
                                ? 1 : 0
                        )
                        .foregroundStyle(.secondary)
                    Text("Type")
                        .opacity(
                            khAccess.state.eqs[selectedEq].enabled[selectedEqBand]
                                ? 0 : 1
                        )
                }

                Spacer()

                Picker(
                    "Type:",
                    selection: $khAccess.state.eqs[selectedEq].type[selectedEqBand]
                ) {
                    ForEach(Eq.EqType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: khAccess.state.eqs[selectedEq].type) {
                    Task {
                        try await khAccess.send()
                    }
                }
                .disabled(khAccess.state.eqs[selectedEq].enabled[selectedEqBand])
            }

            EqSlideriOS(
                binding: $khAccess.state.eqs[selectedEq].frequency,
                name: "Frequency",
                unit: "Hz",
                range: 10...24000,
                logarithmic: true,
                selectedEqBand: selectedEqBand,
                khAccess: khAccess
            )
            EqSlideriOS(
                binding: $khAccess.state.eqs[selectedEq].q,
                name: "Q",
                unit: nil,
                range: 0.1...16,
                logarithmic: true,
                selectedEqBand: selectedEqBand,
                khAccess: khAccess
            )
            EqSlideriOS(
                binding: $khAccess.state.eqs[selectedEq].boost,
                name: "Boost",
                unit: "dB",
                range: -99...24,
                logarithmic: false,
                selectedEqBand: selectedEqBand,
                khAccess: khAccess
            )
            EqSlideriOS(
                binding: $khAccess.state.eqs[selectedEq].gain,
                name: "Makeup",
                unit: "dB",
                range: -99...24,
                logarithmic: false,
                selectedEqBand: selectedEqBand,
                khAccess: khAccess
            )
        }
    }
}

struct EqBandPanelmacOS: View {
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    var selectedEqBand: Int

    var body: some View {
        VStack(spacing: 20) {
            // EQ Type picker
            HStack {
                Picker(
                    "Type:",
                    selection: $khAccess.state.eqs[selectedEq].type[selectedEqBand]
                ) {
                    ForEach(Eq.EqType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: khAccess.state.eqs[selectedEq].type) {
                    Task {
                        try await khAccess.send()
                    }
                }
                .disabled(khAccess.state.eqs[selectedEq].enabled[selectedEqBand])

                Spacer()

                if khAccess.state.eqs[selectedEq].enabled[selectedEqBand] {
                    Text("Disable to change type")
                }
            }

            Grid(alignment: .topLeading) {
                GridRow {
                    EqSlidermacOS(
                        binding: $khAccess.state.eqs[selectedEq].frequency,
                        name: "Frequency",
                        unit: "Hz",
                        range: 10...24000,
                        logarithmic: true,
                        selectedEqBand: selectedEqBand,
                        khAccess: khAccess
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        binding: $khAccess.state.eqs[selectedEq].q,
                        name: "Q",
                        unit: nil,
                        range: 0.1...16,
                        logarithmic: true,
                        selectedEqBand: selectedEqBand,
                        khAccess: khAccess
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        binding: $khAccess.state.eqs[selectedEq].boost,
                        name: "Boost",
                        unit: "dB",
                        range: -99...24,
                        logarithmic: false,
                        selectedEqBand: selectedEqBand,
                        khAccess: khAccess
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        binding: $khAccess.state.eqs[selectedEq].gain,
                        name: "Makeup",
                        unit: "dB",
                        range: -99...24,
                        logarithmic: false,
                        selectedEqBand: selectedEqBand,
                        khAccess: khAccess
                    )
                }
            }
        }

    }
}

struct EqBandPanel: View {
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    var selectedEqBand: Int

    var body: some View {
        #if os(macOS)
            EqBandPanelmacOS(
                khAccess: khAccess,
                selectedEq: selectedEq,
                selectedEqBand: selectedEqBand
            )
        #elseif os(iOS)
            EqBandPaneliOS(
                khAccess: khAccess,
                selectedEq: selectedEq,
                selectedEqBand: selectedEqBand
            )
        #endif
    }
}

struct EqPanel_: View {
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
                khAccess: khAccess,
                selectedEq: selectedEq,
                selectedEqBand: selectedEqBand
            )
        }
    }
}

struct EqPanel: View {
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

                EqPanel_(
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
    EqPanel(khAccess: khAccess)
        .task {
            do {
                try await khAccess.fetch()
            } catch {
                return
            }
        }
}
