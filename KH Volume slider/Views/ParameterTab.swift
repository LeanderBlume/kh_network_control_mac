//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

struct LimitsView: View {
    var limits: OSCLimits

    var body: some View {
        if let desc = limits.desc {
            LabeledContent {
                Text(desc)
            } label: {
                Text("Description")
            }
        }
        if let type = limits.type {
            LabeledContent {
                Text(type)
            } label: {
                Text("Type")
            }
        }
        if let option = limits.option {
            LabeledContent {
                Text(option.map({ "\"" + $0 + "\"" }).joined(separator: ", "))
            } label: {
                Text("Options")
            }
        }
        if let units = limits.units {
            LabeledContent {
                Text(units)
            } label: {
                Text("Units")
            }
        }
        if let min = limits.min {
            LabeledContent {
                Text(String(min))
            } label: {
                Text("Min")
            }
        }
        if let max = limits.max {
            LabeledContent {
                Text(String(max))
            } label: {
                Text("Max")
            }
        }
        if let inc = limits.inc {
            LabeledContent {
                Text(String(inc))
            } label: {
                Text("Increment")
            }
        }
        if let subscr = limits.subscr {
            LabeledContent {
                Text(String(subscr))
            } label: {
                Text("Subscribeable")
            }
        }
        if let const = limits.const {
            LabeledContent {
                Text(String(const))
            } label: {
                Text("Constant")
            }
        }
        if let writeable = limits.writeable {
            LabeledContent {
                Text(String(writeable))
            } label: {
                Text("Writeable")
            }
        }
        if let count = limits.count {
            LabeledContent {
                Text(String(count))
            } label: {
                Text("Count")
            }
        }
    }
}

struct NodeValueEditor: View {
    var node: SSCNode
    @State var valueString: String = ""
    @State var valueNumber: Double = 0
    @State var valueBool: Bool = false
    @State var valueArrayString: [String] = []
    @State var valueArrayNumber: [Double] = []
    @State var valueArrayBool: [Bool] = []

    private func initValue() {
        switch node.value {
        case .value(let T):
            switch T {
            case .string(let v):
                valueString = v
            case .number(let v):
                valueNumber = v
            case .bool(let v):
                valueBool = v
            case .array:
                if let v = T.asArrayBool() {
                    valueArrayBool = v
                } else if let v = T.asArrayNumber() {
                    valueArrayNumber = v
                } else if let v = T.asArrayString() {
                    valueArrayString = v
                }
            default:
                return
            }
        default:
            return
        }
    }

    private func updateNode() {
        switch node.value {
        case .value(let T):
            switch T {
            case .string:
                node.value = NodeData(value: valueString)
            case .number:
                node.value = NodeData(value: valueNumber)
            case .bool:
                node.value = NodeData(value: valueBool)
            case .array:
                if T.asArrayBool() != nil {
                    node.value = NodeData(value: valueArrayBool)
                } else if T.asArrayNumber() != nil {
                    node.value = NodeData(value: valueArrayNumber)
                } else if T.asArrayString() != nil {
                    node.value = NodeData(value: valueArrayString)
                }
            default:
                return
            }
        default:
            return
        }
    }

    private func sendValue() async {
        updateNode()
        do {
            try await node.sendLeaf()
        } catch {
            print("Sending node failed with: \(error)")
        }
    }

    @ViewBuilder
    private func singleValueEditor(_ jsonType: JSONData) -> some View {
        switch jsonType {
        case .string:
            LabeledContent {
                TextField("Node data", text: $valueString)
            } label: {
                Text("Data")
            }
        case .number:
            let precision = (node.limits?.inc == 1) ? 0 : 1
            LabeledContent {
                TextField(
                    "Node data",
                    value: $valueNumber,
                    format: .number.precision(.fractionLength(precision))
                )
            } label: {
                Text("Data")
            }
        case .bool:
            Toggle("Node data", isOn: $valueBool)
        case .object:
            Text("Can't edit non-leaf node")
        case .null:
            Text("null")
        case .array:
            Text("Builder does not support arrays")
        }
    }

    @ViewBuilder
    private func pickerEditor(options: [String]) -> some View {
        Picker("Option", selection: $valueString) {
            ForEach(options, id: \.self) { option in
                Text("\"" + option + "\"").tag(option)
            }
        }
    }

    @ViewBuilder
    private func arrayEditor(_ data: JSONData?) -> some View {
        // The view doesn't appear at all if there's nothing here. I don't know why.
        Text(node.name)
        switch data {
        case .string:
            ForEach(valueArrayString.indices, id: \.self) { i in
                LabeledContent {
                    TextField("Entry \(i + 1)", text: $valueArrayString[i])
                        // .textFieldStyle(.plain)
                } label: {
                    Text("Entry \(i + 1)")
                }
            }
        case .number:
            let precision = (node.limits?.inc == 1) ? 0 : 1
            ForEach(valueArrayNumber.indices, id: \.self) { i in
                LabeledContent {
                    TextField(
                        "Entry \(i + 1)",
                        value: $valueArrayNumber[i],
                        format: .number.precision(.fractionLength(precision))
                    )
                    // .textFieldStyle(.plain)
                } label: {
                    Text("Entry \(i + 1)")
                }
            }
        case .bool:
            ForEach(valueArrayBool.indices, id: \.self) { i in
                Toggle("Entry \(i + 1)", isOn: $valueArrayBool[i])
            }
        case .none:
            Text("Empty Array")
        case .null:
            Text("Array of nulls")
        case .array, .object:
            Text("Nested arrays not supported")
        }
    }

    @ViewBuilder
    private func arrayPickerEditor(options: [String]) -> some View {
        Text(node.name)
        ForEach(valueArrayString.indices, id: \.self) { i in
            Picker("Entry \(i + 1)", selection: $valueArrayString[i]) {
                ForEach(options, id: \.self) { option in
                    Text("\"" + option + "\"").tag(option)
                }
            }
        }
    }

    var body: some View {
        switch node.value {
        case .value(let T):
            switch T {
            case .bool, .number, .string, .null:
                if let option = node.limits?.option {
                    pickerEditor(options: option)
                        .onAppear { initValue() }
                        .disabled(node.limits?.isWriteable == false)
                } else {
                    singleValueEditor(T)
                        .onAppear { initValue() }
                        .disabled(node.limits?.isWriteable == false)
                }
            case .array(let vs):
                if let option = node.limits?.option {
                    arrayPickerEditor(options: option)
                        .onAppear { initValue() }
                        .disabled(node.limits?.isWriteable == false)
                } else {
                    arrayEditor(vs.first)
                        .onAppear { initValue() }
                        .disabled(node.limits?.isWriteable == false)
                }
            case .object:
                Text("Can't edit non-leaf node")
            }
        default:
            Text("Can't edit non-leaf node")
        }
        Button("Send to device") { Task { await sendValue() } }
    }
}

struct NodeView: View {
    var node: SSCNode
    @State var mappedParameter: KHParameters?

    var body: some View {
        Form {
            Section("Edit value") {
                NodeValueEditor(node: node)
            }
            Section("Parameter info (/osc/limits)") {
                if let limits = node.limits {
                    LimitsView(limits: limits)
                } else {
                    LabeledContent {
                        Text("Container")
                    } label: {
                        Text("Type")
                    }
                }
            }
            // TODO maybe make this read-only.
            Section("UI Mapping") {
                Picker("UI Element", selection: $mappedParameter) {
                    Text("None").tag(nil as KHParameters?)
                    ForEach(KHParameters.allCases) { parameter in
                        Text(parameter.rawValue).tag(parameter)
                    }
                }
                .onAppear {
                    KHParameters.allCases.forEach { parameter in
                        if parameter.getDevicePath() == node.pathToNode() {
                            mappedParameter = parameter
                            return
                        }
                    }
                }
                .onChange(of: mappedParameter) {
                    // TODO check type and stuff?
                    if let mappedParameter {
                        mappedParameter.setDevicePath(to: node.pathToNode())
                    }
                }
                Button("Reset All") {
                    KHParameters.resetAllDevicePaths()
                }
            }
        }
    }
}

struct DeviceBrowser: View {
    var rootNode: SSCNode
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private enum Errors: Error {
        case noDevicesFound
    }

    @ViewBuilder
    private func description(_ node: SSCNode) -> some View {
        /// Ideas:
        /// - Colors for different types (at least expandable / not expandable

        HStack {
            let unitString =
                node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""
            Text(node.name + unitString)

            Spacer()

            switch node.value {
            case .unknown, .unknownValue, .unknownChildren:
                ProgressView()
                    #if os(macOS)
                        .scaleEffect(0.5)
                    #endif
            case .error(let s):
                Label(s, systemImage: "exclamationmark.circle")
            case .children:
                EmptyView()
            case .value(let v):
                Text(v.stringify())
                    .foregroundColor(.secondary)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(
                rootNode.children ?? [rootNode],
                children: \.children,
            ) { node in
                switch node.value {
                case .unknown:
                    Button("Query parameters") {
                        Task {
                            await khAccess.populateParameters()
                        }
                    }
                default:
                    NavigationLink(destination: NodeView(node: node)) {
                        description(node)
                    }
                }
            }
            .refreshable { await khAccess.populateParameters() }
        }
    }
}

struct ParameterMapper: View {
    var parameter: KHParameters
    var rootNode: SSCNode
    @Binding var pathStrings: [String: String]
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Text(parameter.rawValue)
        // let pathString: String = pathStrings[parameter.rawValue] ?? "unknown"
        // Text("Current mapping: " + pathString)
        List(
            rootNode.children ?? [rootNode],
            children: \.children,
        ) { node in
            let unitString =
                node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""
            let s = node.name + unitString

            switch node.value {
            case .value, .error:
                Button(s) {
                    // TODO check type and stuff?
                    parameter.setDevicePath(to: node.pathToNode())
                    pathStrings[parameter.rawValue] = parameter.getPathString()
                }
            case .unknown:
                Button("Query parameters") {
                    Task {
                        await khAccess.populateParameters()
                    }
                }
            default:
                Text(s)
            }
        }
    }
}

struct ParameterTab: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var pathStrings: [String: String] = [:]

    func updatePathStrings() {
        for parameter in KHParameters.allCases {
            pathStrings[parameter.rawValue] = parameter.getPathString()
        }
    }

    var body: some View {
        let devices = khAccess.devices
        if devices.isEmpty {
            Text("No devices")
        } else {
            NavigationStack {
                List {
                    Section("Devices") {
                        ForEach(devices) { device in
                            NavigationLink(
                                device.state.name,
                                destination: DeviceBrowser(
                                    rootNode: device.parameterTree
                                )
                            )
                        }
                    }
                    Section("Map UI Elements") {
                        Button("Reset all") {
                            KHParameters.resetAllDevicePaths()
                            updatePathStrings()
                        }
                        ForEach(KHParameters.allCases) { parameter in
                            LabeledContent {
                                NavigationLink(
                                    pathStrings[parameter.rawValue] ?? "unknown",
                                    destination: ParameterMapper(
                                        parameter: parameter,
                                        rootNode: devices.first!.parameterTree,
                                        pathStrings: $pathStrings
                                    )
                                )
                            } label: {
                                Text(parameter.rawValue)
                            }
                        }
                    }
                    .onAppear { updatePathStrings() }
                }
            }
        }
    }
}

#Preview {
    let khAccess = KHAccess()
    ParameterTab().environment(khAccess)
        .task {
            await khAccess.setup()
        }
}
