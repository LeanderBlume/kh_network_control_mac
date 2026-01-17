//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

enum UILeafNodeType {
    case number(Double)
    case bool(Bool)
    case string(String)
    case arrayNumber([Double])
    case arrayString([String])
    case arrayBool([Bool])
    case stringPicker(String, [String])
    case arrayStringPicker([String], [String])

    init?(jsonData: JSONData, limits: OSCLimits?) {
        switch jsonData {
        case .object, .null:
            return nil
        case .bool(let v):
            self = .bool(v)
        case .string(let s):
            if let options = limits?.option {
                self = .stringPicker(s, options)
            } else {
                self = .string(s)
            }
        case .number(let v):
            self = .number(v)
        case .array(let a):
            switch a.first {
            case nil:
                return nil
            case .bool:
                if let raw = jsonData.asArrayBool() {
                    self = .arrayBool(raw)
                } else {
                    return nil
                }
            case .number:
                if let raw = jsonData.asArrayNumber() {
                    self = .arrayNumber(raw)
                } else {
                    return nil
                }
            case .string:
                if let raw = jsonData.asArrayString() {
                    if let options = limits?.option {
                        self = .arrayStringPicker(raw, options)
                    } else {
                        self = .arrayString(raw)
                    }
                } else {
                    return nil
                }
            case .null, .object, .array:
                return nil
            }
        }
    }
}

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
    @State var pickerOptions: [String] = []

    private func initValue() {
        switch node.value {
        case .value(let T):
            switch UILeafNodeType(jsonData: T, limits: node.limits) {
            case .string(let v):
                valueString = v
            case .number(let v):
                valueNumber = v
            case .bool(let v):
                valueBool = v
            case .arrayBool(let v):
                valueArrayBool = v
            case .arrayNumber(let v):
                valueArrayNumber = v
            case .arrayString(let v):
                valueArrayString = v
            case .stringPicker(let v, let options):
                valueString = v
                pickerOptions = options
            case .arrayStringPicker(let v, let options):
                valueArrayString = v
                pickerOptions = options
            case .none:
                return
            }
        default:
            return
        }
    }

    private func updateNode() {
        switch node.value {
        case .value(let T):
            switch UILeafNodeType(jsonData: T, limits: node.limits) {
            case .number:
                node.value = NodeData(value: valueNumber)
            case .bool:
                node.value = NodeData(value: valueBool)
            case .string, .stringPicker:
                node.value = NodeData(value: valueString)
            case .arrayBool:
                node.value = NodeData(value: valueArrayBool)
            case .arrayNumber:
                node.value = NodeData(value: valueArrayNumber)
            case .arrayString, .arrayStringPicker:
                node.value = NodeData(value: valueArrayString)
            case .none:
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

    var body: some View {
        switch node.value {
        case .value(let T):
            switch UILeafNodeType(jsonData: T, limits: node.limits) {
            case .string:
                TextField("Data", text: $valueString)
                    .textFieldStyle(.plain)
            case .number:
                let precision = (node.limits?.inc == 1) ? 0 : 1
                TextField(
                    "Data",
                    value: $valueNumber,
                    format: .number.precision(.fractionLength(precision))
                )
                .textFieldStyle(.plain)
            case .bool:
                Toggle("Data", isOn: $valueBool)
            case .arrayBool:
                ForEach(valueArrayBool.indices, id: \.self) { i in
                    Toggle("Entry \(i + 1)", isOn: $valueArrayBool[i])
                }
            case .arrayNumber:
                let precision = (node.limits?.inc == 1) ? 0 : 1
                ForEach(valueArrayNumber.indices, id: \.self) { i in
                    TextField(
                        "Entry \(i + 1)",
                        value: $valueArrayNumber[i],
                        format: .number.precision(.fractionLength(precision))
                    )
                    .textFieldStyle(.plain)
                }
            case .arrayString:
                ForEach(valueArrayString.indices, id: \.self) { i in
                    TextField("Entry \(i + 1)", text: $valueArrayString[i])
                        .textFieldStyle(.plain)
                }
            case .stringPicker:
                Picker("Option", selection: $valueString) {
                    ForEach(pickerOptions, id: \.self) { option in
                        Text("\"" + option + "\"").tag(option)
                    }
                }
            case .arrayStringPicker:
                ForEach(valueArrayString.indices, id: \.self) { i in
                    Picker("Entry \(i + 1)", selection: $valueArrayString[i]) {
                        ForEach(pickerOptions, id: \.self) { option in
                            Text("\"" + option + "\"").tag(option)
                        }
                    }
                }
            case .none:
                Text("Non-leaf node or unknown type")
            }
        default:
            Text("Can't edit non-leaf node")
        }

        Button("Send to device") { Task { await sendValue() } }
            .onAppear { initValue() }
            .disabled(node.limits?.isWriteable == false)
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
            // Should this be read-only?
            Section("UI Mapping") {
                Picker("UI Element", selection: $mappedParameter) {
                    Text("None").tag(nil as KHParameters?)
                    ForEach(KHParameters.allCases) { parameter in
                        Text(parameter.rawValue).tag(parameter)
                    }
                }
                .onAppear {
                    // Check if this path is already mapped to a parameter.
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

    var body: some View {
        NavigationStack {
            List(
                rootNode.children ?? [rootNode],
                children: \.children,
            ) { node in
                let unitString =
                    node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""

                switch node.value {
                case .unknown:
                    Button("Query parameters") {
                        Task {
                            await khAccess.populateParameters()
                        }
                    }
                default:
                    NavigationLink(destination: NodeView(node: node)) {
                        HStack {
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
    @State var selection: SSCNode.ID? = nil
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private func setParameter() {
        guard let node = rootNode.first(where: { $0.id == selection }) else {
            return
        }
        parameter.setDevicePath(to: node.pathToNode())
        pathStrings[parameter.rawValue] = parameter.getPathString()
    }

    var body: some View {
        List(
            rootNode.children ?? [rootNode],
            children: \.children,
            selection: $selection
        ) { node in
            let unitString =
                node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""
            let s = node.name + unitString

            switch node.value {
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
        .navigationTitle(Text(parameter.rawValue))
        .overlay(alignment: .bottom) {
            Button(action: setParameter) {
                if let selection = selection {
                    VStack {
                        Text(pathStrings[parameter.rawValue] ?? "unknown")
                            .strikethrough(true)
                        if let node = rootNode.first(where: { $0.id == selection }) {
                            Label(
                                "/" + node.pathToNode().joined(separator: "/"),
                                systemImage: "arrow.right"
                            )
                        } else {
                            Label("Node doesn't exist", systemImage: "arrow.right")
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("Select a node")
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
            .disabled(selection == nil)
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
                                .navigationTitle(device.state.name)
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
                    .onAppear(perform: updatePathStrings)
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
