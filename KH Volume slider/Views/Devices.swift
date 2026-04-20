//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

private enum UILeafNodeType {
    case number(Double)
    case bool(Bool)
    case string(String)
    case arrayNumber([Double], Int)
    case arrayString([String], Int)
    case arrayBool([Bool], Int)
    case stringPicker(String, [String])
    case arrayStringPicker([String], Int, [String])

    init?(jsonData: JSONData, limits: OSCLimits?) {
        switch jsonData {
        case .object, .null:
            return nil
        case .bool(let v):
            self = .bool(v)
        case .number(let v):
            self = .number(v)
        case .string(let s):
            if let options = limits?.option {
                self = .stringPicker(s, options)
            } else {
                self = .string(s)
            }
        case .array(let a):
            switch a.first {
            case .bool:
                guard let raw: [Bool] = jsonData.asType() else { return nil }
                self = .arrayBool(raw, raw.count)
            case .number:
                guard let raw: [Double] = jsonData.asType() else { return nil }
                self = .arrayNumber(raw, raw.count)
            case .string:
                guard let raw: [String] = jsonData.asType() else { return nil }
                if let options = limits?.option {
                    self = .arrayStringPicker(raw, raw.count, options)
                } else {
                    self = .arrayString(raw, raw.count)
                }
            case .none, .null, .object, .array:
                return nil
            }
        }
    }
}

// seems like it should be an enum. But maybe not, I don't know how bindings to enum values work.
@MainActor
private struct PossibleValues {
    var string: String = ""
    var number: Double = 0
    var bool: Bool = false
    var arrayString: [String] = []
    var arrayNumber: [Double] = []
    var arrayBool: [Bool] = []
    var pickerOptions: [String] = []

    init(fromNode node: SSCNode) {
        switch node.value {
        case .value(let T):
            switch UILeafNodeType(jsonData: T, limits: node.limits) {
            case .string(let v):
                string = v
            case .number(let v):
                number = v
            case .bool(let v):
                bool = v
            case .arrayBool(let v, _):
                arrayBool = v
            case .arrayNumber(let v, _):
                arrayNumber = v
            case .arrayString(let v, _):
                arrayString = v
            case .stringPicker(let v, let options):
                string = v
                pickerOptions = options
            case .arrayStringPicker(let v, _, let options):
                arrayString = v
                pickerOptions = options
            case .none:
                return
            }
        default:
            return
        }
    }

    func updateNode(node: SSCNode) {
        switch node.value {
        case .value(let T):
            switch UILeafNodeType(jsonData: T, limits: node.limits) {
            case .number:
                node.value = NodeData(value: number)
            case .bool:
                node.value = NodeData(value: bool)
            case .string, .stringPicker:
                node.value = NodeData(value: string)
            case .arrayBool:
                node.value = NodeData(value: arrayBool)
            case .arrayNumber:
                node.value = NodeData(value: arrayNumber)
            case .arrayString, .arrayStringPicker:
                node.value = NodeData(value: arrayString)
            case .none:
                return
            }
        default:
            return
        }
    }
}

private struct LimitsView: View {
    var limits: OSCLimits

    var body: some View {
        if let desc = limits.desc {
            LabeledContent {
                Text(desc)
            } label: {
                Text("Description:")
            }
        }
        if let type = limits.type {
            LabeledContent {
                Text(type)
            } label: {
                Text("Type:")
            }
        }
        if let option = limits.option {
            LabeledContent {
                Text(option.map({ "\"" + $0 + "\"" }).joined(separator: ", "))
            } label: {
                Text("Options:")
            }
        }
        if let units = limits.units {
            LabeledContent {
                Text(units)
            } label: {
                Text("Units:")
            }
        }
        if let min = limits.min {
            LabeledContent {
                Text(String(min))
            } label: {
                Text("Min:")
            }
        }
        if let max = limits.max {
            LabeledContent {
                Text(String(max))
            } label: {
                Text("Max:")
            }
        }
        if let inc = limits.inc {
            LabeledContent {
                Text(String(inc))
            } label: {
                Text("Increment:")
            }
        }
        if let subscr = limits.subscr {
            LabeledContent {
                Text(String(subscr))
            } label: {
                Text("Subscribeable:")
            }
        }
        if let const = limits.const {
            LabeledContent {
                Text(String(const))
            } label: {
                Text("Constant:")
            }
        }
        if let writeable = limits.writeable {
            LabeledContent {
                Text(String(writeable))
            } label: {
                Text("Writeable:")
            }
        }
        if let count = limits.count {
            LabeledContent {
                Text(String(count))
            } label: {
                Text("Count:")
            }
        }
    }
}

private struct NodeValueEditor: View {
    var type: UILeafNodeType
    @Binding var values: PossibleValues
    var precision: Int

    var body: some View {
        switch type {
        /*
        case .none:
            Text("Non-leaf node or unknown type")
         */
        case .string:
            TextField("String", text: $values.string)
        case .number:
            TextField(
                "Number",
                value: $values.number,
                format: .number.precision(.fractionLength(precision))
            )
        case .bool:
            Toggle("true/false", isOn: $values.bool)
        case .arrayBool(_, let count):
            ForEach(values.arrayBool.indices, id: \.self) { i in
                Toggle("true/false (\(i + 1)/\(count))", isOn: $values.arrayBool[i])
            }
        case .arrayNumber(_, let count):
            ForEach($values.arrayNumber.indices, id: \.self) { i in
                TextField(
                    "Number (\(i + 1)/\(count))",
                    value: $values.arrayNumber[i],
                    format: .number.precision(.fractionLength(precision))
                )
            }
        case .arrayString(_, let count):
            ForEach(values.arrayString.indices, id: \.self) { i in
                TextField("String (\(i + 1)/\(count))", text: $values.arrayString[i])
            }
        case .stringPicker:
            Picker("Option", selection: $values.string) {
                ForEach(values.pickerOptions, id: \.self) { option in
                    Text("\"" + option + "\"").tag(option)
                }
            }
        case .arrayStringPicker(_, let count, _):
            ForEach($values.arrayString.indices, id: \.self) { i in
                Picker("Option (\(i + 1)/\(count))", selection: $values.arrayString[i])
                {
                    ForEach(values.pickerOptions, id: \.self) { option in
                        Text("\"" + option + "\"").tag(option)
                    }
                }
            }
        }
    }
}

private struct NodeValueView: View {
    var node: SSCNode
    @Binding var values: PossibleValues
    var stateManager: StateManager
    var mappedParameters: [SSCParameter]
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private func sendValue() async {
        values.updateNode(node: node)
        guard let device = khAccess.getDeviceByID(node.id.deviceID) else {
            print("Device with id \(node.id.deviceID) not found")
            return
        }
        guard
            var deviceState = stateManager.deviceStates.first(where: {
                $0.deviceID == device.id
            })
        else {
            print("No matching device state found")
            return
        }
        let deviceStateIndex = stateManager.deviceStates.firstIndex(of: deviceState)!
        for p in mappedParameters {
            guard let newState = p.set(node: node, into: deviceState) else { break }
            deviceState = newState
        }
        stateManager.deviceStates[deviceStateIndex] = deviceState
        await device.sendNode(path: node.pathToNode())
    }

    var body: some View {
        Group {
            switch node.value {
            case .value(let T):
                if let type = UILeafNodeType(jsonData: T, limits: node.limits) {
                    let precision = (node.limits?.inc == 1) ? 0 : 1
                    NodeValueEditor(type: type, values: $values, precision: precision)
                } else {
                    Text("Non-leaf node or unknown type")
                }
            default:
                Text("Can't edit non-leaf node")
            }

            Button("Send to device", systemImage: "square.and.arrow.up") {
                Task { await sendValue() }
            }
        }
        .disabled(node.limits?.isWriteable == false)
    }
}

private struct NodeView: View {
    var node: SSCNode
    @State private var values: PossibleValues
    var stateManager: StateManager
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private var deviceName: String {
        khAccess.getDeviceByID(node.id.deviceID)?.state.name ?? "Non-existent device"
    }

    init(node: SSCNode, stateManager: StateManager) {
        self.node = node
        values = .init(fromNode: node)
        self.stateManager = stateManager
    }

    private func getMappedParameters() -> [SSCParameter] {
        guard let device = khAccess.getDeviceByID(node.id.deviceID) else {
            print("Device with id \(node.id.deviceID) not found")
            return []
        }
        let deviceModel = device.getModel()
        // Check if this path is already mapped to a parameter.
        return deviceModel.allParameters().filter {
            deviceModel.getDevicePath(for: $0) == node.pathToNode()
        }
    }

    var bodyiOS: some View {
        Form {
            Section("Edit value(s)") {
                NodeValueView(
                    node: node,
                    values: $values,
                    stateManager: stateManager,
                    mappedParameters: getMappedParameters()
                )
            }

            #if os(macOS)
                Divider()
            #endif

            Section("Parameter info (/osc/limits)") {
                if let limits = node.limits {
                    LimitsView(limits: limits)
                } else {
                    LabeledContent {
                        Text("Container")
                    } label: {
                        Text("Type:")
                    }
                }
            }

            #if os(macOS)
                Divider()
            #endif

            Section("UI Mapping") {
                LabeledContent {
                    Text(getMappedParameters().first?.description() ?? "None")
                } label: {
                    Text("Mapped to:")
                }
            }
        }
        .refreshable {
            guard let device = khAccess.getDeviceByID(node.id.deviceID) else {
                print("Device with id \(node.id.deviceID) not found")
                return
            }
            await device.fetchNode(path: node.pathToNode())
            values = .init(fromNode: node)
        }
        .navigationTitle(deviceName + ":" + node.getPathString())
    }

    var bodymacOS: some View {
        ScrollView {
            VStack {
                Text(deviceName + ":" + node.getPathString()).font(.title2)

                bodyiOS
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

private struct DeviceBrowser: View {
    var rootNode: SSCNode
    var stateManager: StateManager
    var deviceName: String {
        khAccess.getDeviceByID(rootNode.id.deviceID)?.state.name
            ?? "Non-existent device"
    }
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        VStack {
            #if os(macOS)
                Text(deviceName).font(.title2)
            #endif

            List(
                rootNode.children ?? [],
                children: \.children,
            ) { node in
                NavigationLink(
                    destination: NodeView(node: node, stateManager: stateManager)
                ) {
                    if let units = node.limits?.units {
                        Text(node.name + " (\(units))")
                    } else {
                        Text(node.name)
                    }

                    // This spacer can cause an EXC_BAD_ACCESS on the macOS build. Super weird.
                    // Actually it doesn't cause it, but not having it reduces occurences and also maybe it looks better.
                    // Spacer()

                    switch node.value {
                    case .unknown, .unknownValue, .unknownChildren:
                        Text("unknown")
                    case .error(let s):
                        Label(s, systemImage: "exclamationmark.circle")
                    case .children:
                        EmptyView()
                    case .value(let v):
                        Text(v.stringify()).foregroundColor(.secondary)
                    }
                }
            }
            .refreshable { await khAccess.fetchParameterTree() }
            .navigationTitle(deviceName)
        }
    }
}

private struct ParameterMapper: View {
    var parameter: SSCParameter
    var rootNode: SSCNode
    @Binding var pathString: String?
    @State var selection: SSCNode.ID? = nil
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private func setParameter() {
        guard let device = khAccess.getDeviceByID(rootNode.id.deviceID) else {
            print("Device with id \(rootNode.id.deviceID) not found")
            return
        }
        let deviceModel = device.getModel()
        guard let selection else { return }
        guard let node = khAccess.getNodeByID(selection) else { return }
        deviceModel.setDevicePath(for: parameter, to: node.pathToNode())
        pathString = deviceModel.getPathString(for: parameter)
    }

    var body: some View {
        VStack {
            #if os(macOS)
                Text("Remapping UI element: \(parameter.description())").font(.title2)
            #endif

            List(
                rootNode.children ?? [rootNode],
                children: \.children,
                selection: $selection
            ) { node in
                let unitString =
                    node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""
                Text(node.name + unitString)
            }
            .navigationTitle(Text(parameter.description()))
            .overlay(alignment: .bottom) {
                Button(action: setParameter) {
                    if let selection {
                        VStack {
                            Text(pathString ?? "unknown")
                                .strikethrough(true)
                            if let node = khAccess.getNodeByID(selection) {
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
}

private struct DeviceBrowserLink: View {
    var device: KHDevice
    var stateManager: StateManager

    var body: some View {
        if let rootNode = device.parameterTree {
            NavigationLink(
                destination: DeviceBrowser(
                    rootNode: rootNode,
                    stateManager: stateManager
                )
            ) {
                Text(device.state.name)
                Text(device.getModel().description())
                    .foregroundStyle(.secondary)
            }
        } else {
            LabeledContent {
                if device.status == .ready {
                    Text("Parameters not loaded")
                } else {
                    StatusDisplayText(status: device.status)
                }
            } label: {
                Text(device.state.name)
            }
        }
    }
}

private struct ParameterMapperLink: View {
    var parameter: SSCParameter
    var rootNode: SSCNode
    @Binding var pathString: String?

    var body: some View {
        LabeledContent {
            NavigationLink(
                pathString ?? "unknown",
                destination: ParameterMapper(
                    parameter: parameter,
                    rootNode: rootNode,
                    pathString: $pathString
                )
            )
        } label: {
            Text(parameter.description())
        }
    }
}

private struct ParameterMappingForDeviceModel: View {
    var deviceModel: DeviceModel
    @State private var pathStrings: [SSCParameter.ID: String] = [:]
    @Environment(KHAccess.self) private var khAccess: KHAccess

    private func updatePathStrings() {
        for parameter in deviceModel.allParameters() {
            pathStrings[parameter.id] = deviceModel.getPathString(for: parameter)
        }
    }

    private func getMatchingRootNode() -> SSCNode? {
        khAccess.getDeviceByModel(deviceModel)?.parameterTree
    }

    var body: some View {
        VStack {
            #if os(macOS)
                Text("UI mappings for \(deviceModel.description())")
                    .font(.title2)
            #endif

            List {
                Button("Reset all") {
                    deviceModel.resetAllDevicePaths()
                    updatePathStrings()
                }
                if let rootNode = getMatchingRootNode() {
                    ForEach(deviceModel.allParameters()) { parameter in
                        ParameterMapperLink(
                            parameter: parameter,
                            rootNode: rootNode,
                            pathString: $pathStrings[parameter.id]
                        )
                    }
                    .onAppear(perform: updatePathStrings)
                } else {
                    Text("Failed to find matching parameter tree")
                }
            }
            .navigationTitle("UI mappings for " + deviceModel.description())
        }
    }
}

private struct DeviceBrowserForm: View {
    var devices: [KHDevice]
    var stateManager: StateManager

    var deviceModels: [DeviceModel] {
        let models = devices.map({ $0.getModel() })
        return Array(Set(models)).sorted { $0.description() < $1.description() }
    }

    var body: some View {
        List {
            Section("Parameter Browser") {
                ForEach(devices) { device in
                    DeviceBrowserLink(device: device, stateManager: stateManager)
                }
            }
            Section("UI mappings") {
                ForEach(deviceModels) { deviceModel in
                    NavigationLink(
                        deviceModel.description(),
                        destination: ParameterMappingForDeviceModel(
                            deviceModel: deviceModel
                        )
                    )
                }
            }
        }
    }
}

struct DevicesView: View {
    var stateManager: StateManager

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var pathStrings: [String: String] = [:]

    var body: some View {
        let devices = khAccess.devices.sorted { $0.state.name < $1.state.name }
        NavigationStack {
            if devices.isEmpty {
                Text("No devices")
            } else {
                DeviceBrowserForm(devices: devices, stateManager: stateManager)
            }
        }
    }
}
