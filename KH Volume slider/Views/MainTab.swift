//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import Foundation
import SwiftUI

private struct AutoStandbySection: View {
    @Binding var uiState: KHState
    var sendCallback: () async -> Void
    @FocusState.Binding var textFieldFocused: Bool

    @ViewBuilder
    var bodyiOS: some View {
        Toggle("Enable", isOn: $uiState.standbyEnabled)
            .onChange(of: uiState.standbyEnabled) {
                Task { await sendCallback() }
            }

        LabeledContent {
            TextField(
                "Auto-standby timeout",
                value: $uiState.standbyTimeout,
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
        Picker("Timeout (minutes)", selection: $uiState.standbyTimeout) {
            ForEach(3...240, id: \.self) { i in
                Text("\(i)").tag(i)
            }
        }
        #if os(iOS)
            .pickerStyle(.wheel)
        #endif
          */
    }

    var bodymacOS: some View {
        Grid(alignment: .leading) {
            GridRow {
                Text("Enable")

                Toggle("Enable auto-standby", isOn: $uiState.standbyEnabled)
                    .labelsHidden()
                    .onChange(of: uiState.standbyEnabled) {
                        Task { await sendCallback() }
                    }

                Spacer()
            }
            GridRow {
                Text("Timeout (minutes)")

                TextField(
                    "Timeout",
                    value: $uiState.standbyTimeout,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback() } }

                Spacer()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}

private struct IndividualDeviceSection: View {
    @Binding var uiState: KHState
    var sendCallback: () async -> Void

    @FocusState.Binding var textFieldFocused: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ViewBuilder
    var bodyiOS: some View {
        TextField("Name", text: $uiState.name)
            .onSubmit { Task { await sendCallback() } }

        Toggle("Identify (flash LED)", isOn: $uiState.identify)
            .onChange(of: uiState.identify) {
                Task { await sendCallback() }
            }

        Grid {
            LabeledSliderTextField(
                name: "Delay (1/48 kHz)",
                value: $uiState.delay,
                range: 0...5760,
                sendCallback: sendCallback,
                precision: 0
            )
        }
    }

    var bodymacOS: some View {
        Grid(alignment: .leading) {
            GridRow {
                Text("Name")

                TextField("Name", text: $uiState.name)
                    .frame(width: 80)
                    .onSubmit { Task { await sendCallback() } }
                    .labelsHidden()

                Spacer()
            }
            GridRow {
                Text("Identify (flash LED)")

                Toggle("Toggle", isOn: $uiState.identify)
                    .onChange(of: uiState.identify) {
                        Task { await sendCallback() }
                    }
                    .toggleStyle(.button)

                Spacer()
            }
            GridRow {
                Text("Delay (1/48 kHz)")

                Slider(value: $uiState.delay, in: 0...5760) {
                    editing in
                    if !editing { Task { await sendCallback() } }
                }

                TextField(
                    "Delay (1/48 kHz)",
                    value: $uiState.delay,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback() } }
                .labelsHidden()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}

private enum SelectedDevice: Hashable {
    case all
    case specific(Int)
}

private struct MainTab_: View {
    @Binding var uiState: KHState
    var selectedDevice: SelectedDevice

    var sendCallback: () async -> Void

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState private var textFieldFocused: Bool
    @State private var showError: Bool = false

    @ViewBuilder
    var bodyiOS: some View {
        if case .specific = selectedDevice {
            Section("Individual device") {
                IndividualDeviceSection(
                    uiState: $uiState,
                    sendCallback: sendCallback,
                    textFieldFocused: $textFieldFocused
                )
            }
        }

        Section("Volume (dB)") {
            LabeledContent {
                TextField(
                    "",
                    value: $uiState.volume,
                    format: .number.precision(.fractionLength(1))
                )
                .onSubmit { Task { await sendCallback() } }
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
            } label: {
                Text("dB:").foregroundColor(.secondary)
            }

            Slider(value: $uiState.volume, in: 0...120, step: 3) {
                Text("")
            } onEditingChanged: { editing in
                if !editing { Task { await sendCallback() } }
            }

            Stepper(
                "+/- 1 db",
                value: $uiState.volume,
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
                isOn: $uiState.muted
            )
            // .toggleStyle(.button)
            .onChange(of: uiState.muted) { Task { await sendCallback() } }
        }
        .focused($textFieldFocused)
        .disabled(khAccess.status != .ready)

        Section("Logo brightness") {
            TextField(
                "",
                value: $uiState.logoBrightness,
                format: .percent.scale(1).precision(.fractionLength(0))
            )
            .onSubmit { Task { await sendCallback() } }
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif

            Slider(value: $uiState.logoBrightness, in: 0...125, step: 5) {
                Text("")
            } onEditingChanged: { editing in
                if !editing { Task { await sendCallback() } }
            }
        }
        .focused($textFieldFocused)
        .disabled(khAccess.status != .ready)

        Section("EQ") {
            EqTab(eqs: $uiState.eqs, sendCallback: sendCallback)
        }
        .focused($textFieldFocused)
        .disabled(khAccess.status != .ready)

        Section("Auto-standby") {
            AutoStandbySection(
                uiState: $uiState,
                sendCallback: sendCallback,
                textFieldFocused: $textFieldFocused
            )
        }
    }

    @ViewBuilder
    var bodymacOS: some View {
        if case .specific = selectedDevice {
            Text("Individual device")
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            IndividualDeviceSection(
                uiState: $uiState,
                sendCallback: sendCallback,
                textFieldFocused: $textFieldFocused
            )
        }

        Text("Basic controls")
            .font(.title2)
            .frame(maxWidth: .infinity, alignment: .leading)

        Grid(alignment: .leading) {
            GridRow {
                Text("Mute")
                Toggle(
                    "Toggle",
                    systemImage: "speaker.slash.fill",
                    isOn: $uiState.muted
                )
                .toggleStyle(.button)
                // .toggleStyle(.switch)
                .onChange(of: uiState.muted) {
                    Task { await sendCallback() }
                }
                .disabled(khAccess.status != .ready)
                .labelsHidden()
                // .padding(.bottom, 10)
            }
            GridRow {
                Text("Volume (dB)")

                Slider(value: $uiState.volume, in: 0...120, step: 3) {
                    editing in
                    if !editing { Task { await sendCallback() } }
                }

                TextField(
                    "Volume",
                    value: $uiState.volume,
                    format: .number.precision(.fractionLength(1))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback() } }
                .labelsHidden()
            }
            GridRow {
                Text("Logo")

                Slider(value: $uiState.logoBrightness, in: 0...125, step: 5) {
                    editing in
                    if !editing { Task { await sendCallback() } }
                }

                TextField(
                    "Logo",
                    value: $uiState.logoBrightness,
                    format: .percent.scale(1).precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback() } }
                .labelsHidden()
            }
        }

        Text("EQ").font(.title2)
            .frame(maxWidth: .infinity, alignment: .leading)

        EqTab(eqs: $uiState.eqs, sendCallback: sendCallback)

        Text("Auto-standby").font(.title2)
            .frame(maxWidth: .infinity, alignment: .leading)

        AutoStandbySection(
            uiState: $uiState,
            sendCallback: sendCallback,
            textFieldFocused: $textFieldFocused
        )
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}

struct MainTab: View {
    @Binding var commonState: KHState
    @Binding var deviceStates: [KHState]
    var fetchCallback: () async -> Void
    var connectCallback: () async -> Void
    var rescanCallback: () async -> Void
    var clearCacheCallback: () async -> Void

    @State private var selectedDevice: SelectedDevice = .all
    @State private var showError: Bool = false
    @FocusState private var textFieldFocused: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    func sendCallback() async {
        switch selectedDevice {
        case .all:
            await khAccess.send(commonState)
        case .specific(let i):
            await khAccess.sendIdentified(deviceStates[i])
        }
    }

    var bodyiOS: some View {
        Form {
            Picker("Device:", selection: $selectedDevice) {
                Text("All").tag(SelectedDevice.all)

                ForEach(deviceStates.indices, id: \.self) { i in
                    Text(deviceStates[i].name).tag(SelectedDevice.specific(i))
                }
            }
            .pickerStyle(.segmented)

            switch selectedDevice {
            case .all:
                MainTab_(
                    uiState: $commonState,
                    selectedDevice: selectedDevice,
                    sendCallback: sendCallback
                )
            case .specific(let i):
                MainTab_(
                    uiState: $deviceStates[i],
                    selectedDevice: selectedDevice,
                    sendCallback: sendCallback
                )
            }
        }
        .toolbar(removing: .title)
        .toolbar {
            MainToolbar(
                showError: $showError,
                fetchCallback: fetchCallback,
                connectCallback: connectCallback,
                rescanCallback: rescanCallback,
                clearCacheCallback: clearCacheCallback
            )
            if textFieldFocused {
                ToolbarDoneAndCancel(
                    textFieldFocused: $textFieldFocused,
                    sendCallback: sendCallback
                )
            }
        }
    }

    var bodymacOS: some View {
        VStack(spacing: 20) {
            Picker("Device:", selection: $selectedDevice) {
                Text("All").tag(SelectedDevice.all)

                ForEach(deviceStates.indices, id: \.self) { i in
                    Text(deviceStates[i].name).tag(SelectedDevice.specific(i))
                }
            }
            .pickerStyle(.segmented)

            switch selectedDevice {
            case .all:
                MainTab_(
                    uiState: $commonState,
                    selectedDevice: selectedDevice,
                    sendCallback: sendCallback
                )
            case .specific(let i):
                MainTab_(
                    uiState: $deviceStates[i],
                    selectedDevice: selectedDevice,
                    sendCallback: sendCallback
                )
            }
        }
        .disabled(khAccess.status != .ready)
        .toolbar {
            MainToolbar(
                showError: $showError,
                fetchCallback: fetchCallback,
                connectCallback: connectCallback,
                rescanCallback: rescanCallback,
                clearCacheCallback: clearCacheCallback
            )
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}
