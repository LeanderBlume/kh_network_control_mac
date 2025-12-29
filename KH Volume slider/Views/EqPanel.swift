//
//  EqPanel.swift
//  KH Volume slider
//
//  Created by Leander Blume on 14.01.25.
//

import SwiftUI

struct EqSlider: View {
    var binding: Binding<[Double]>
    var name: String
    var unit: String?
    var range: ClosedRange<Double>
    var logarithmic: Bool
    var selectedEqBand: Int
    var khAccess: KHAccess

    var body: some View {
        let unitString: String = unit != nil ? " (\(unit!))" : ""

        #if os(macOS)
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
        #elseif os(iOS)
            VStack {
                Text(name + unitString)

                HStack {
                    if logarithmic {
                        Slider.withLog2Scale(value: binding[selectedEqBand], in: range)
                        {
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
        #endif
    }
}

struct EqBandPanel: View {
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    var selectedEqBand: Int

    var body: some View {
        #if os(macOS)
            VStack(spacing: 20) {
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

                    Text("Disable to change type")
                        .opacity(
                            khAccess.state.eqs[selectedEq].enabled[selectedEqBand]
                                ? 1 : 0
                        )
                }

                Grid(alignment: .topLeading) {
                    GridRow {
                        EqSlider(
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
                        EqSlider(
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
                        EqSlider(
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
                        EqSlider(
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
        #elseif os(iOS)
            VStack {
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

                EqSlider(
                    binding: $khAccess.state.eqs[selectedEq].frequency,
                    name: "Frequency",
                    unit: "Hz",
                    range: 10...24000,
                    logarithmic: true,
                    selectedEqBand: selectedEqBand,
                    khAccess: khAccess
                )
                EqSlider(
                    binding: $khAccess.state.eqs[selectedEq].q,
                    name: "Q",
                    unit: nil,
                    range: 0.1...16,
                    logarithmic: true,
                    selectedEqBand: selectedEqBand,
                    khAccess: khAccess
                )
                EqSlider(
                    binding: $khAccess.state.eqs[selectedEq].boost,
                    name: "Boost",
                    unit: "dB",
                    range: -99...24,
                    logarithmic: false,
                    selectedEqBand: selectedEqBand,
                    khAccess: khAccess
                )
                EqSlider(
                    binding: $khAccess.state.eqs[selectedEq].gain,
                    name: "Makeup",
                    unit: "dB",
                    range: -99...24,
                    logarithmic: false,
                    selectedEqBand: selectedEqBand,
                    khAccess: khAccess
                )
            }
        #endif
    }
}

struct EqPanel_: View {
    @Bindable var khAccess: KHAccess
    var selectedEq: Int
    @State var selectedEqBand: Int = 0

    var body: some View {
        let numBands = khAccess.state.eqs[selectedEq].enabled.count

        VStack(spacing: 20) {
            #if os(macOS)
                Grid(horizontalSpacing: 30, verticalSpacing: 20) {
                    ForEach((1...numBands / 10), id: \.self) { row in
                        GridRow {
                            ForEach((10 * (row - 1)...10 * row - 1), id: \.self) { i in
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
                            }
                        }
                    }
                }
            #elseif os(iOS)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach((0..<numBands), id: \.self) { i in
                            VStack(alignment: .center) {
                                Button(String(i + 1)) {
                                    selectedEqBand = i
                                }
                                .foregroundStyle(
                                    selectedEqBand == i ? .green : .accentColor
                                )
                                // .background(selectedEqBand == i ? .green : .clear)
                                
                                Toggle(
                                    "✓",
                                    isOn: $khAccess.state.eqs[selectedEq]
                                        .enabled[i]
                                )
                                .toggleStyle(.button)
                            }
                            // .frame(width: 50)
                            .padding(.bottom)
                        }
                    }
                }
                .scrollClipDisabled(true)
            #endif
            EqBandPanel(
                khAccess: khAccess,
                selectedEq: selectedEq,
                selectedEqBand: selectedEqBand
            )
        }
        .onChange(
            of: khAccess.state.eqs[selectedEq].enabled
        ) {
            print("I WAS CHANGED")
            Task {
                try await khAccess.send()
            }
        }
    }
}

struct EqPanel: View {
    var khAccess: KHAccess
    @State private var selectedEq: Int = 0

    var body: some View {
        ScrollView {
            EqChart(state: khAccess.state).frame(height: 150)

            VStack(spacing: 20) {
                Picker("", selection: $selectedEq) {
                    Text("post EQ").tag(0)
                    Text("calibration EQ").tag(1)
                }
                .pickerStyle(.segmented)

                ZStack {
                    EqPanel_(khAccess: khAccess, selectedEq: 0)
                        .opacity(selectedEq == 0 ? 1 : 0)
                    EqPanel_(khAccess: khAccess, selectedEq: 1)
                        .opacity(selectedEq == 1 ? 1 : 0)
                }
            }
            .padding()
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
