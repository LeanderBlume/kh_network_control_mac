//
//  SSCTreeView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.25.
//

import SwiftUI

struct SSCTreeView: View {
    var khAccess: KHAccess
    @State var selectedNode: SSCNode.ID?

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
        List(
            khAccess.parameters.first!.children ?? [],
            children: \.children,
            selection: $selectedNode
        ) {
            description($0)
        }
        .task { await buildTree() }
        /// TODO write a different method that just re-fetches leaf node values?
        // .refreshable { await buildTree() }
    }
}

#Preview {
    SSCTreeView(khAccess: KHAccess())
}
