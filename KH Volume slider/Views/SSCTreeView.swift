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

    var body: some View {
        Text(status)
        List(rootNode?.children ?? [], children: \.children, selection: $selectedNode) {
            item in
            Text(item.description())
        }
        .task {
            status = "Querying..."
            do {
                let scan = SSCDevice.scan()
                if scan.isEmpty {
                    throw Errors.noDevicesFound
                }
                rootNode = SSCNode(device: scan.first!, name: "Root")
                try await rootNode!.populate(recursive: true)
                status = "Querying successful"
            } catch {
                rootNode = nil
                status = "Scan failed"
            }
        }
    }
}

#Preview {
    SSCTreeView()
}
