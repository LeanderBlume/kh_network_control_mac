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
                Text(v.stringify())
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
            .refreshable { await khAccess.populateParameters() }
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
                SSCTreeView(rootNode: khAccess.devices[selectedDevice].parameterTree)
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    ParameterTab().environment(KHAccess())
}
