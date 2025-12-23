//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

struct SSCTreeView: View {
    @State var rootNode: SSCNode?
    @State var selectedNode: SSCNode.ID?
    @State var status = "Idle"

    private enum Errors: Error {
        case noDevicesFound
    }
    
    @ViewBuilder
    private func description(_ node: SSCNode) -> some View {
        HStack {
            Text(node.name)
            Spacer()
            switch node.value {
            case .none:
                Text("unknown subtree")
            case .null:
                Text("unknown value")
            case .error(let s):
                Text("ERROR: " + s)
            case .object:
                EmptyView()
            case .string(let v):
                Text(#"""# + v + #"""#)
            case .number(let v):
                Text(String(v))
            case .bool(let v):
                Text(v ? "yes" : "no")
            case .arrayString(let v):
                Text(String(describing: v))
            case .arrayNumber(let v):
                Text(String(describing: v))
            case .arrayBool(let v):
                Text(String(describing: v))
            }
        }
    }

    var body: some View {
        Text(status)
        List(rootNode?.children ?? [], children: \.children, selection: $selectedNode) {
            node in description(node)
        }
        .task {
            status = "Querying..."
            do {
                let scan = SSCDevice.scan()
                if scan.isEmpty {
                    status = "Scan found no devices"
                    throw Errors.noDevicesFound
                }
                rootNode = SSCNode(device: scan.first!, name: "Root")
                try await rootNode!.connect()
                try await rootNode!.populate(recursive: true)
                rootNode!.disconnect()
                status = "Querying successful"
            } catch {
                rootNode = nil
                status = "Querying failed"
            }
        }
    }
}

#Preview {
    SSCTreeView()
}
