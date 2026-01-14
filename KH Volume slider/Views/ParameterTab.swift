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

struct NodeView: View {
    var node: SSCNode
    @State var mappedParameter: KHParameters?

    var body: some View {
        Form {
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
                    // TODO check type and stuff
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

struct SSCTreeView: View {
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
                    Text("Refresh to query")
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
    @State var currentMapping: [String]

    init(parameter: KHParameters, rootNode: SSCNode) {
        self.parameter = parameter
        self.rootNode = rootNode
        currentMapping = parameter.getDevicePath()
        print(currentMapping)
    }

    var body: some View {
        if rootNode.value == .unknown {
            Text("Current mapping: /" + currentMapping.joined(separator: "/"))
            Text("Query parameters to see available ones.")
        } else {
            Text("Current mapping: /" + currentMapping.joined(separator: "/"))
            List(
                rootNode.children ?? [],
                children: \.children,
            ) { node in
                let unitString =
                    node.limits?.units != nil ? " (" + node.limits!.units! + ")" : ""
                let s = node.name + unitString

                switch node.value {
                case .value, .error:
                    Button(s) {
                        currentMapping = node.pathToNode()
                        parameter.setDevicePath(to: currentMapping)
                    }
                default:
                    Text(s)
                }
            }
        }
    }
}

struct ParameterTab: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        if khAccess.devices.isEmpty {
            Text("No devices")
        } else {
            NavigationStack {
                List {
                    if khAccess.devices.first!.parameterTree.value == .unknown {
                        Button("Query parameters") {
                            Task {
                                await khAccess.populateParameters()
                            }
                        }
                    }
                    Section("Device List") {
                        ForEach(khAccess.devices) { device in
                            NavigationLink(
                                device.state.name,
                                destination: SSCTreeView(rootNode: device.parameterTree)
                            )
                        }
                    }
                    Section("Map UI Elements") {
                        Button("Reset all") {
                            KHParameters.resetAllDevicePaths()
                        }
                        ForEach(KHParameters.allCases) { parameter in
                            NavigationLink(
                                parameter.rawValue,
                                destination: ParameterMapper(
                                    parameter: parameter,
                                    rootNode: khAccess.devices.first!.parameterTree
                                )
                            )
                            /*
                            LabeledContent {
                                NavigationLink(
                                    "/" + parameter.getDevicePath().joined(separator: "/"),
                                    destination: ParameterMapper(
                                        parameter: parameter,
                                        rootNode: khAccess.devices.first!.parameterTree
                                    )
                                )
                            } label: {
                                Text(parameter.rawValue)
                            }
                             */
                        }
                    }
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
