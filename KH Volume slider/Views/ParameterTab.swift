//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

struct SSCTreeView: View {
    var rootNode: SSCNode
    @State var selectedNode: SSCNode.ID?
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
                /*
                if let jsonData = try? JSONEncoder().encode(v) {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        // let s = jsonString
                        Text(jsonString)
                    } else {
                        Text("String conversion failed")
                    }
                } else {
                    Text("JSON Encoding failed")
                }
                 */
                // It works and it's stupid.
                let jsonData = try! JSONEncoder().encode(v)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                switch v {
                case .string(let v):
                    Text("\"" + v + "\"")
                case .number(let v):
                    if node.limits!.inc == 1 {
                        Text(String(Int(v)))
                    } else {
                        Text(String(v))
                    }
                case .bool(let v):
                    // Text(v ? "yes" : "no")
                    Text(String(v))
                case .array(let vs):
                    switch vs.first {
                    case .string:
                        if let A = v.asArrayString() {
                            Text(String(describing: A))
                        } else {
                            Text(String(describing: vs))
                        }
                    case .number:
                        if let A = v.asArrayNumber() {
                            if node.limits?.inc == 1 {
                                Text(String(describing: A.map({ Int($0) })))
                            } else {
                                Text(String(describing: A))
                            }
                        } else {
                            Text(String(describing: vs))
                        }
                    case .bool:
                        if let A = v.asArrayBool() {
                            Text(String(describing: A))
                        } else {
                            Text(String(describing: vs))
                        }
                    default:
                        Text("Weird array")
                    }
                default:
                    Text("Weird value")
                }
            }
        }
    }

    var body: some View {
        if rootNode.value == .unknown {
            Button("Query parameters") {
                Task {
                    await khAccess.populateParameters()
                }
            }
        } else {
            List(
                rootNode.children ?? [],
                children: \.children,
                selection: $selectedNode
            ) {
                description($0)
            }
            // .task { await buildTree() }
            /// TODO write a different method that just re-fetches leaf node values?
            // .refreshable { await buildTree() }
        }
    }
}

struct ParameterTab: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var selectedDevice: Int = 0

    var body: some View {
        if khAccess.devices.isEmpty {
            Text("No devices")
        } else {
            VStack {
                Picker("", selection: $selectedDevice) {
                    Text("1").tag(0)
                    Text("2").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer()
                SSCTreeView(rootNode: khAccess.devices[selectedDevice].parameters)
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    ParameterTab().environment(KHAccess())
}
