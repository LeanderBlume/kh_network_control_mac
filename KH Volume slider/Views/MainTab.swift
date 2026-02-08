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

    @ToolbarContentBuilder
    var standardToolbar: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showError.toggle()
                } label: {
                    StatusDisplayCompact(status: khAccess.status)
                        .popover(
                            isPresented: $showError,
                            attachmentAnchor: .point(.bottom)
                        ) {
                            StatusDisplayText(status: khAccess.status)
                                .padding(.horizontal)
                                .presentationCompactAdaptation(.popover)
                        }
                }
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())
            Button("Fetch parameters", systemImage: "square.and.arrow.down") {
                Task { await khAccess.fetchParameters() }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Fetch", systemImage: "arrow.clockwise") {
                Task { await khAccess.fetch() }
            }
            .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
        }
    }

    @ToolbarContentBuilder
    var doneAndCancel: some ToolbarContent {
        // ToolbarItemGroup(placement: .keyboard) {
        ToolbarItem(placement: .confirmationAction) {
            // Spacer()
            Button("Done", systemImage: "checkmark") {
                Task { await khAccess.send() }
                textFieldFocused = false
            }
            .buttonStyle(.borderedProminent)
        }
        ToolbarItem(placement: .cancellationAction) {
            // Spacer()
            Button("Cancel", systemImage: "keyboard.chevron.compact.down") {
                textFieldFocused = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

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
        .toolbar {
            if textFieldFocused {
                doneAndCancel
            } else {
                standardToolbar
            }
        }
    }
}

struct MainTabmacOS: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    @ToolbarContentBuilder
    var standardToolbar: some ToolbarContent {
        ToolbarItem(placement: .status) {
            Button {
                showError.toggle()
            } label: {
                StatusDisplayCompact(status: khAccess.status)
                    .popover(
                        isPresented: $showError,
                        attachmentAnchor: .point(.top)
                    ) {
                        StatusDisplayText(status: khAccess.status).padding()
                    }
            }
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())
            Button("Fetch parameters", systemImage: "square.and.arrow.down") {
                Task { await khAccess.fetchParameters() }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Fetch", systemImage: "arrow.clockwise") {
                Task { await khAccess.fetch() }
            }
            .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
        }
    }

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
        .toolbar { standardToolbar }
    }
}
