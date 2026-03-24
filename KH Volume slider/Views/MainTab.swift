//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import Foundation
import SwiftUI

struct MainTabiOS: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState private var textFieldFocused: Bool
    @State private var showError: Bool = false

    var body: some View {
        @Bindable var khAccess = khAccess

        Form {
            Section("Volume (dB)") {
                LabeledContent {
                    TextField(
                        "",
                        value: $khAccess.state.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .onSubmit { Task { await khAccess.send() } }
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                } label: {
                    Text("dB:").foregroundColor(.secondary)
                }

                Slider(value: $khAccess.state.volume, in: 0...120, step: 3) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await khAccess.send() } }
                }

                Stepper(
                    "+/- 1 db",
                    value: $khAccess.state.volume,
                    in: 0...120,
                    step: 1
                ) {
                    editing in
                    if editing { return }
                    Task { await khAccess.send() }
                }

                Toggle(
                    "Mute",
                    systemImage: "speaker.slash.fill",
                    isOn: $khAccess.state.muted
                )
                // .toggleStyle(.button)
                .onChange(of: khAccess.state.muted) { Task { await khAccess.send() } }
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("Logo brightness") {
                TextField(
                    "",
                    value: $khAccess.state.logoBrightness,
                    format: .percent.scale(1).precision(.fractionLength(0))
                )
                .onSubmit { Task { await khAccess.send() } }
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif

                Slider(value: $khAccess.state.logoBrightness, in: 0...125, step: 5) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await khAccess.send() } }
                }
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("EQ") {
                EqTab()
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("Auto-standby") {
                Toggle("Enable", isOn: $khAccess.state.standbyEnabled)
                    .onChange(of: khAccess.state.standbyEnabled) {
                        Task { await khAccess.send() }
                    }

                LabeledContent {
                    TextField(
                        "Auto-standby timeout",
                        value: $khAccess.state.standbyTimeout,
                        format: .number.precision(.fractionLength(0))
                    )
                    .focused($textFieldFocused)
                    .onSubmit { Task { await khAccess.send() } }
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                } label: {
                    Text("Timeout (minutes):")
                }
            }
        }
        .toolbar(removing: .title)
        .toolbar {
            MainToolbar(showError: $showError)
            if textFieldFocused {
                ToolbarDoneAndCancel(textFieldFocused: $textFieldFocused)
            }
        }
    }
}

struct MainTabmacOS: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var body: some View {
        @Bindable var khAccess = khAccess

        VStack(spacing: 20) {
            // Text("Controls").font(.title)
            //     .frame(maxWidth: .infinity, alignment: .leading)

            Text("Basic controls").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading) {
                GridRow {
                    Text("Mute")
                    Toggle(
                        "Toggle",
                        systemImage: "speaker.slash.fill",
                        isOn: $khAccess.state.muted
                    )
                    .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: khAccess.state.muted) {
                        Task { await khAccess.send() }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                    // .padding(.bottom, 10)
                }
                GridRow {
                    Text("Volume (dB)")

                    Slider(value: $khAccess.state.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await khAccess.send() } }
                    }

                    TextField(
                        "Volume",
                        value: $khAccess.state.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send() } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $khAccess.state.logoBrightness, in: 0...125, step: 5)
                    { editing in
                        if !editing { Task { await khAccess.send() } }
                    }

                    TextField(
                        "Logo",
                        value: $khAccess.state.logoBrightness,
                        format: .percent.scale(1).precision(.fractionLength(0))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send() } }
                    .labelsHidden()
                }
            }

            Text("EQ").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            EqTab()

            Text("Auto-standby").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading) {
                GridRow {
                    Text("Enable")

                    Toggle("Enable auto-standby", isOn: $khAccess.state.standbyEnabled)
                        .labelsHidden()
                        .onChange(of: khAccess.state.standbyEnabled) {
                            Task { await khAccess.send() }
                        }

                    Spacer()
                }
                GridRow {
                    Text("Timeout (minutes)")

                    TextField(
                        "Timeout",
                        value: $khAccess.state.standbyTimeout,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send() } }

                    Spacer()
                }
            }
        }
        .disabled(khAccess.status != .ready)
        .toolbar { MainToolbar(showError: $showError) }
    }
}
