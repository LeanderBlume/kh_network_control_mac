//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import Foundation
import SwiftUI

struct DelaySection: View {
    @State var deviceStates: [KHState]
    @Environment(KHAccess.self) private var khAccess: KHAccess

    func sendCallback() async {
        await khAccess.sendIndividual(deviceStates)
    }

    func fetch() async {
        deviceStates = await khAccess.fetchAll()
    }

    var body: some View {

    }
}

struct MainTab: View {
    @Binding var commonState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState private var textFieldFocused: Bool
    @State private var showError: Bool = false

    func sendCallback() async { await khAccess.send(commonState) }

    @ViewBuilder
    var bodyiOS: some View {
        Form {
            Section("Volume (dB)") {
                LabeledContent {
                    TextField(
                        "",
                        value: $commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .onSubmit { Task { await sendCallback() } }
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                } label: {
                    Text("dB:").foregroundColor(.secondary)
                }

                Slider(value: $commonState.volume, in: 0...120, step: 3) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await sendCallback() } }
                }

                Stepper(
                    "+/- 1 db",
                    value: $commonState.volume,
                    in: 0...120,
                    step: 1
                ) {
                    editing in
                    if editing { return }
                    Task { await sendCallback() }
                }

                Toggle(
                    "Mute",
                    systemImage: "speaker.slash.fill",
                    isOn: $commonState.muted
                )
                // .toggleStyle(.button)
                .onChange(of: commonState.muted) { Task { await sendCallback() } }
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("Logo brightness") {
                TextField(
                    "",
                    value: $commonState.logoBrightness,
                    format: .percent.scale(1).precision(.fractionLength(0))
                )
                .onSubmit { Task { await sendCallback() } }
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif

                Slider(value: $commonState.logoBrightness, in: 0...125, step: 5) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await sendCallback() } }
                }
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("EQ") {
                EqTab(eqs: $commonState.eqs, sendCallback: sendCallback)
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("Auto-standby") {
                Toggle("Enable", isOn: $commonState.standbyEnabled)
                    .onChange(of: commonState.standbyEnabled) {
                        Task { await sendCallback() }
                    }

                LabeledContent {
                    TextField(
                        "Auto-standby timeout",
                        value: $commonState.standbyTimeout,
                        format: .number.precision(.fractionLength(0))
                    )
                    .focused($textFieldFocused)
                    .onSubmit { Task { await sendCallback() } }
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                } label: {
                    Text("Timeout (minutes):")
                }
                /*
                Picker("Timeout (minutes)", selection: $commonState.standbyTimeout) {
                    ForEach(3...240, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                #if os(iOS)
                    .pickerStyle(.wheel)
                #endif
                  */
            }
        }
        .toolbar(removing: .title)
        .toolbar {
            MainToolbar(commonState: $commonState, showError: $showError)
            if textFieldFocused {
                ToolbarDoneAndCancel(
                    textFieldFocused: $textFieldFocused,
                    sendCallback: sendCallback
                )
            }
        }
    }

    @ViewBuilder
    var bodymacOS: some View {
        VStack(spacing: 20) {
            Text("Basic controls").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading) {
                GridRow {
                    Text("Mute")
                    Toggle(
                        "Toggle",
                        systemImage: "speaker.slash.fill",
                        isOn: $commonState.muted
                    )
                    .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: commonState.muted) {
                        Task { await sendCallback() }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                    // .padding(.bottom, 10)
                }
                GridRow {
                    Text("Volume (dB)")

                    Slider(value: $commonState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await sendCallback() } }
                    }

                    TextField(
                        "Volume",
                        value: $commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await sendCallback() } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $commonState.logoBrightness, in: 0...125, step: 5) {
                        editing in
                        if !editing { Task { await sendCallback() } }
                    }

                    TextField(
                        "Logo",
                        value: $commonState.logoBrightness,
                        format: .percent.scale(1).precision(.fractionLength(0))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await sendCallback() } }
                    .labelsHidden()
                }
            }

            Text("EQ").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            EqTab(eqs: $commonState.eqs, sendCallback: sendCallback)

            Text("Auto-standby").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading) {
                GridRow {
                    Text("Enable")

                    Toggle("Enable auto-standby", isOn: $commonState.standbyEnabled)
                        .labelsHidden()
                        .onChange(of: commonState.standbyEnabled) {
                            Task { await sendCallback() }
                        }

                    Spacer()
                }
                GridRow {
                    Text("Timeout (minutes)")

                    TextField(
                        "Timeout",
                        value: $commonState.standbyTimeout,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await sendCallback() } }

                    Spacer()
                }
            }
        }
        .disabled(khAccess.status != .ready)
        .toolbar { MainToolbar(commonState: $commonState, showError: $showError) }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}
