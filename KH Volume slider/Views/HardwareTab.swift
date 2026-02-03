//
//  UIView2.swift
//  KH Volume slider
//
//  Created by Leander Blume on 26.01.25.
//

import SwiftUI

struct HardwareTab: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState private var textFieldFocused: Bool
    @State private var showError: Bool = false

    @ToolbarContentBuilder
    var standardToolbarWithDoneButton: some ToolbarContent {
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
        if textFieldFocused {
            // ToolbarItemGroup(placement: .keyboard) {
            ToolbarItemGroup(placement: .confirmationAction) {
                // Spacer()
                Button("Done", systemImage: "checkmark") {
                    Task { await khAccess.send() }
                    textFieldFocused = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    var body: some View {
        @Bindable var khAccess = khAccess

        #if os(macOS)
            HStack {
                Text("Logo brightness")
                Slider(value: $khAccess.state.logoBrightness, in: 0...125) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing {
                        Task {
                            await khAccess.send()
                        }
                    }
                }

                TextField(
                    "Logo brightness",
                    value: $khAccess.state.logoBrightness,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await khAccess.send() } }
            }
        #elseif os(iOS)
            VStack {
                Text("Logo brightness")

                HStack {
                    Slider(value: $khAccess.state.logoBrightness, in: 0...125) {
                        Text("")
                    } onEditingChanged: { editing in
                        if !editing {
                            Task {
                                await khAccess.send()
                            }
                        }
                    }
                    .disabled(!khAccess.status.isClean())

                    TextField(
                        "Logo brightness",
                        value: $khAccess.state.logoBrightness,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 80)
                    .keyboardType(.numberPad)
                    .focused($textFieldFocused)
                    .onSubmit {
                        Task { await khAccess.send() }
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
            // .toolbarVisibility(.hidden, for: .tabBar)
            .toolbar { standardToolbarWithDoneButton }
        #endif
    }
}

#Preview {
    HardwareTab().environment(KHAccess())
}
