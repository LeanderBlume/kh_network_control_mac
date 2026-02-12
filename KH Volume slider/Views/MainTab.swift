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
            Section("Volume") {
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

                Slider(value: $khAccess.state.volume, in: 0...120) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await khAccess.send() } }
                }

                Stepper(
                    "+/- 3 db",
                    value: $khAccess.state.volume,
                    in: 0...120,
                    step: 3
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

                Slider(value: $khAccess.state.logoBrightness, in: 0...125) {
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
        }
        .toolbar(removing: .title)
        .toolbar {
            if textFieldFocused {
                ToolbarDoneAndCancel(textFieldFocused: $textFieldFocused)
            } else {
                MainToolbar(showError: $showError)
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

            Grid(alignment: .topLeading) {
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
                    LabeledSliderTextField(
                        name: "Volume",
                        value: $khAccess.state.volume,
                        range: 0...120
                    )
                }
                GridRow {
                    LabeledSliderTextField(
                        name: "Logo",
                        value: $khAccess.state.logoBrightness,
                        range: 0...125
                    )
                }
            }

            Text("EQ").font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            EqTab()
        }
        .disabled(khAccess.status != .ready)
        .toolbar { MainToolbar(showError: $showError) }
    }
}
