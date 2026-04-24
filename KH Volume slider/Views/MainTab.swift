//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import Foundation
import SwiftUI

private enum SelectedDevice: Hashable {
    case all
    case specific(_ deviceIndex: Int)
}

private struct AutoStandbySection: View {
    @Binding var uiState: KHState
    var sendCallback: (SSCParameter) async -> Void
    @FocusState.Binding var textFieldFocused: SSCParameter?

    @ViewBuilder
    var bodyiOS: some View {
        Toggle("Enable", isOn: $uiState.standbyEnabled)
            .onChange(of: uiState.standbyEnabled) {
                Task { await sendCallback(.standbyEnabled) }
            }

        LabeledContent {
            TextField(
                "Auto-standby timeout",
                value: $uiState.standbyTimeout,
                format: .number.precision(.fractionLength(0))
            )
            .focused($textFieldFocused, equals: .standbyTimeout)
            .onSubmit { Task { await sendCallback(.standbyTimeout) } }
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
                        Task { await sendCallback(.standbyEnabled) }
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
                .onSubmit { Task { await sendCallback(.standbyTimeout) } }

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
    var sendCallback: (SSCParameter) async -> Void

    @FocusState.Binding var textFieldFocused: SSCParameter?
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ViewBuilder
    var bodyiOS: some View {
        TextField("Name", text: $uiState.name)
            .focused($textFieldFocused, equals: .name)
            .onSubmit { Task { await sendCallback(.name) } }

        Toggle("Identify (flash LED)", systemImage: "rays", isOn: $uiState.identify)
            .onChange(of: uiState.identify) {
                Task { await sendCallback(.identify) }
            }

        VStack {
            HStack {
                Text("Delay (1/48kHz)" + ":")

                TextField(
                    "Delay (1/48kHz)",
                    value: $uiState.delay,
                    format: .number.precision(.fractionLength(0))
                )
                .focused($textFieldFocused, equals: .delay)
                .onSubmit { Task { await sendCallback(.delay) } }
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }

            Stepper(
                "+/- 1",
                value: $uiState.delay,
                in: 0...5760,
                step: 1
            ) {
                editing in
                if editing { return }
                Task { await sendCallback(.delay) }
            }
        }
    }

    var bodymacOS: some View {
        Grid(alignment: .leading) {
            GridRow {
                Text("Name")

                TextField("Name", text: $uiState.name)
                    .frame(width: 80)
                    .onSubmit { Task { await sendCallback(.name) } }
                    .labelsHidden()

                Spacer()
            }
            GridRow {
                Text("Identify (flash LED)")

                Toggle("Toggle", systemImage: "rays", isOn: $uiState.identify)
                    .onChange(of: uiState.identify) {
                        Task { await sendCallback(.identify) }
                    }
                    .toggleStyle(.button)

                Spacer()
            }
            GridRow {
                Text("Delay (1/48kHz)")

                TextField(
                    "Delay (1/48kHz)",
                    value: $uiState.delay,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback(.delay) } }
                .labelsHidden()

                Stepper(
                    "+/- 1",
                    value: $uiState.delay,
                    in: 0...5760,
                    step: 1
                ) {
                    editing in
                    if editing { return }
                    Task { await sendCallback(.delay) }
                }
                .labelsHidden()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            HStack {
                bodymacOS
                Spacer()
            }
        #endif
    }
}

private struct MainTabForDevice: View {
    @Binding var uiState: KHState
    var deviceStates: [KHState]
    var selectedDevice: SelectedDevice
    var sendCallback: (SSCParameter) async -> Void

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @FocusState.Binding var textFieldFocused: SSCParameter?
    @State private var showError: Bool = false

    func getActiveDeviceModel() -> DeviceModel? {
        switch selectedDevice {
        case .all:
            khAccess.devices.first?.getModel()
        case .specific(let i):
            khAccess.devices[i].getModel()
        }
    }

    @ViewBuilder
    private func mismatchInfo(_ parameters: Set<SSCParameter>) -> some View {
        let mismatchedParameters = Set(
            SSCParameter.allDefaultParameters.filter { !$0.allEqual(deviceStates) }
        )
        let mps = parameters.filter {
            mismatchedParameters.contains($0)
        }
        if selectedDevice == .all && !mps.isEmpty {
            HStack {
                Image(systemName: "info.circle")
                Text(
                    "Device mismatch: "
                        + mps.map({ $0.description() }).sorted().joined(separator: ", ")
                )
            }
            .font(.footnote)
        }
    }

    private func sectionTitleMacOS(
        title: String,
        parametersInSection: Set<SSCParameter>,
    ) -> some View {
        HStack(spacing: 15) {
            Text(title).font(.title2)
            mismatchInfo(parametersInSection)
            Spacer()
        }
    }

    private func sectionTitleiOS(
        title: String,
        parametersInSection: Set<SSCParameter>,
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            mismatchInfo(parametersInSection)
        }
    }

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

        Section {
            LabeledContent {
                TextField(
                    "",
                    value: $uiState.volume,
                    format: .number.precision(.fractionLength(1))
                )
                .onSubmit { Task { await sendCallback(.volume) } }
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
            } label: {
                Text("dB:").foregroundColor(.secondary)
            }

            Slider(value: $uiState.volume, in: 0...120, step: 3) {
                Text("")
            } onEditingChanged: { editing in
                if !editing { Task { await sendCallback(.volume) } }
            }

            Stepper(
                "+/- 1 db",
                value: $uiState.volume,
                in: 0...120,
                step: 1
            ) {
                editing in
                if editing { return }
                Task { await sendCallback(.volume) }
            }

            Toggle(
                "Mute",
                systemImage: "speaker.slash.fill",
                isOn: $uiState.muted
            )
            // .toggleStyle(.button)
            .onChange(of: uiState.muted) { Task { await sendCallback(.muted) } }
        } header: {
            sectionTitleiOS(title: "Volume", parametersInSection: [.volume, .muted])
        }
        .focused($textFieldFocused, equals: .volume)
        .disabled(khAccess.status != .ready)

        Section {
            TextField(
                "",
                value: $uiState.logoBrightness,
                format: .percent.scale(1).precision(.fractionLength(0))
            )
            .onSubmit { Task { await sendCallback(.logoBrightness) } }
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif

            Slider(value: $uiState.logoBrightness, in: 0...125, step: 5) {
                Text("")
            } onEditingChanged: { editing in
                if !editing { Task { await sendCallback(.logoBrightness) } }
            }
        } header: {
            sectionTitleiOS(
                title: "Logo brightness",
                parametersInSection: [.logoBrightness]
            )
        }
        .focused($textFieldFocused, equals: .logoBrightness)
        .disabled(khAccess.status != .ready)

        Section {
            // TODO this is cursed right now and should be changed somehow.
            if let deviceModel = getActiveDeviceModel() {
                EqTab(
                    eqs: $uiState.eqs,
                    sendCallback: sendCallback,
                    deviceModel: deviceModel,
                    textFieldFocused: $textFieldFocused,
                )
            } else {
                Text("Device model could not be determined")
            }
        } header: {
            let eqParams = Set(SSCParameter.allDefaultParameters).filter({
                if case .eq = $0 { true } else { false }
            })

            sectionTitleiOS(title: "EQ", parametersInSection: eqParams)
        }
        .disabled(khAccess.status != .ready)

        Section {
            AutoStandbySection(
                uiState: $uiState,
                sendCallback: sendCallback,
                textFieldFocused: $textFieldFocused
            )
        } header: {
            sectionTitleiOS(
                title: "Auto-standby",
                parametersInSection: [.standbyEnabled, .standbyTimeout]
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

        sectionTitleMacOS(
            title: "Basic controls",
            parametersInSection: [.muted, .volume, .logoBrightness],
        )

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
                    Task { await sendCallback(.muted) }
                }
                .disabled(khAccess.status != .ready)
                .labelsHidden()
                // .padding(.bottom, 10)
            }
            GridRow {
                Text("Volume (dB)")

                Slider(value: $uiState.volume, in: 0...120, step: 3) {
                    editing in
                    if !editing { Task { await sendCallback(.volume) } }
                }

                TextField(
                    "Volume",
                    value: $uiState.volume,
                    format: .number.precision(.fractionLength(1))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback(.volume) } }
                .labelsHidden()
            }
            GridRow {
                Text("Logo")

                Slider(value: $uiState.logoBrightness, in: 0...125, step: 5) {
                    editing in
                    if !editing { Task { await sendCallback(.logoBrightness) } }
                }

                TextField(
                    "Logo",
                    value: $uiState.logoBrightness,
                    format: .percent.scale(1).precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit { Task { await sendCallback(.logoBrightness) } }
                .labelsHidden()
            }
        }

        sectionTitleMacOS(
            title: "EQ",
            parametersInSection: Set(SSCParameter.allDefaultParameters).filter({
                if case .eq = $0 { true } else { false }
            }),
        )

        if let deviceModel = getActiveDeviceModel() {
            EqTab(
                eqs: $uiState.eqs,
                sendCallback: sendCallback,
                deviceModel: deviceModel,
                textFieldFocused: $textFieldFocused
            )
        } else {
            Text("Device model could not be determined")
        }

        sectionTitleMacOS(
            title: "Auto-standby",
            parametersInSection: [.standbyEnabled, .standbyTimeout]
        )

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
    @Binding var stateManager: StateManager

    @State private var selectedDevice: SelectedDevice = .all
    @State private var showError: Bool = false
    @FocusState private var textFieldFocused: SSCParameter?
    @Environment(KHAccess.self) private var khAccess: KHAccess

    func sendCallback(_ parameter: SSCParameter) async {
        switch selectedDevice {
        case .all:
            await stateManager.sendToAll(parameter)
        case .specific:
            await stateManager.sendIndividual()
        }
    }

    var bodyiOS: some View {
        Form {
            Section("Select device") {
                Picker("Device", selection: $selectedDevice) {
                    Text("All").tag(SelectedDevice.all)

                    ForEach(stateManager.deviceStates.indices, id: \.self) { i in
                        Text(stateManager.deviceStates[i].name).tag(
                            SelectedDevice.specific(i)
                        )
                    }
                }
                .pickerStyle(.menu)
            }

            let uiStateBinding =
                switch selectedDevice {
                case .all:
                    $stateManager.commonState
                case .specific(let i):
                    $stateManager.deviceStates[i]
                }

            let navTitle =
                switch selectedDevice {
                case .all:
                    "All"
                case .specific(let i):
                    stateManager.deviceStates[i].name
                }

            MainTabForDevice(
                uiState: uiStateBinding,
                deviceStates: stateManager.deviceStates,
                selectedDevice: selectedDevice,
                sendCallback: sendCallback,
                textFieldFocused: $textFieldFocused
            )
            .id(selectedDevice)
            .navigationTitle(Text(navTitle))
        }
        // .toolbar(removing: .title)
        .toolbar {
            MainToolbar(
                showError: $showError,
                stateManager: stateManager
            )
            if textFieldFocused != nil {
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

                ForEach(stateManager.deviceStates.indices, id: \.self) { i in
                    Text(stateManager.deviceStates[i].name).tag(
                        SelectedDevice.specific(i)
                    )
                }
            }
            .pickerStyle(.menu)

            let uiStateBinding =
                switch selectedDevice {
                case .all:
                    $stateManager.commonState
                case .specific(let i):
                    $stateManager.deviceStates[i]
                }

            MainTabForDevice(
                uiState: uiStateBinding,
                deviceStates: stateManager.deviceStates,
                selectedDevice: selectedDevice,
                sendCallback: sendCallback,
                textFieldFocused: $textFieldFocused
            ).id(selectedDevice)
        }
        .disabled(khAccess.status != .ready)
        .toolbar {
            MainToolbar(
                showError: $showError,
                stateManager: stateManager
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
