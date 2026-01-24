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
                .disabled(!khAccess.status.isClean())

                TextField(
                    "Logo brightness",
                    value: $khAccess.state.logoBrightness,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit {
                    print("SUBMITTED")
                    Task {
                        await khAccess.send()
                    }
                }
            }
        #elseif os(iOS)
            // NavigationView {
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
                            print("SUBMITTED")
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { textFieldFocused = false }
                        }
                    }
                }
            // }
        #endif
    }
}

#Preview {
    HardwareTab().environment(KHAccess())
}
