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

    private func buildTree() async {
        do {
            try await khAccess.populateParameters()
        } catch {
            khAccess.status = .speakersUnavailable
        }
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
            case .none, .null:
                ProgressView()
            case .error(let s):
                Text("⚠️ " + s)
            case .object:
                EmptyView()
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
            case .arrayString(let v):
                Text(String(describing: v))
            case .arrayNumber(let v):
                if node.limits?.inc == 1 {
                    Text(String(describing: v.map({ Int($0) })))
                } else {
                    Text(String(describing: v))
                }
            case .arrayBool(let v):
                Text(String(describing: v))
            }
        }
    }

    var body: some View {
        if rootNode.value == nil {
            Button("Query parameters") {
                Task {
                    await buildTree()
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
        VStack {
            Picker("", selection: $selectedDevice) {
                Text("1").tag(0)
                Text("2").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Spacer()
            SSCTreeView(rootNode: khAccess.parameters[selectedDevice])
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ParameterTab().environment(KHAccess())
}
