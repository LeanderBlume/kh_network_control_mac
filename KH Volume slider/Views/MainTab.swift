//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import Foundation
import SwiftUI

struct MainTab: View {
    @State var khState = KHState()
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState private var textFieldFocused: Bool
    @State private var showError: Bool = false

    @ViewBuilder
    var bodyiOS: some View {
        Form {
            Section("Volume") {
                LabeledContent {
                    TextField(
                        "",
                        value: $khState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .onSubmit { Task { await khAccess.send(khState) } }
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                } label: {
                    Text("dB:").foregroundColor(.secondary)
                }

                Slider(value: $khState.volume, in: 0...120) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await khAccess.send(khState) } }
                }

                Stepper(
                    "+/- 3 db",
                    value: $khState.volume,
                    in: 0...120,
                    step: 3
                ) {
                    editing in
                    if editing { return }
                    Task { await khAccess.send(khState) }
                }

                Toggle(
                    "Mute",
                    systemImage: "speaker.slash.fill",
                    isOn: $khState.muted
                )
                // .toggleStyle(.button)
                .onChange(of: khState.muted) { Task { await khAccess.send(khState) } }
            }
            .focused($textFieldFocused)
            .disabled(khAccess.status != .ready)

            Section("Logo brightness") {
                TextField(
                    "",
                    value: $khState.logoBrightness,
                    format: .percent.scale(1).precision(.fractionLength(0))
                )
                .onSubmit { Task { await khAccess.send(khState) } }
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif

                Slider(value: $khState.logoBrightness, in: 0...125) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing { Task { await khAccess.send(khState) } }
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

    @ViewBuilder
    var bodymacOS: some View {
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
                        isOn: $khState.muted
                    )
                    .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: khState.muted) {
                        Task { await khAccess.send(khState) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                    // .padding(.bottom, 10)
                }
                GridRow {
                    LabeledSliderTextField(
                        name: "Volume",
                        value: $khState.volume,
                        range: 0...120
                    )
                }
                GridRow {
                    LabeledSliderTextField(
                        name: "Logo",
                        value: $khState.logoBrightness,
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

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}
