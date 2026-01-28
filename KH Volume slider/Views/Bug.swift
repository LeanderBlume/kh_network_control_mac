//
//  Bug.swift
//  KH Volume slider
//
//  Created by Leander Blume on 28.01.26.
//

import SwiftUI

struct HierarchicalData: Identifiable {
    var name: String
    var value: Int
    var children: [HierarchicalData]?
    var id = UUID()
}

struct BugView: View {
    let data = HierarchicalData(
        name: "root",
        value: 0,
        children: [
            HierarchicalData(name: "child1", value: 1000),
            HierarchicalData(name: "child2", value: 100)
        ]
    )

    var body: some View {
        NavigationStack {
            List([data], children: \.children) { node in
                NavigationLink(destination: EmptyView()) {
                    Text(node.name)
                    Spacer()
                    Text(String(node.value))
                }
            }
        }
    }
}

#Preview {
    BugView()
}
