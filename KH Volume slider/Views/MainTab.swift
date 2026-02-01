//
//  SwiftUIView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 01.02.26.
//

import SwiftUI

struct MainTab: View {
    var body: some View {
        VStack {
            Spacer()
            VolumeTab()
            Spacer()
            HardwareTab()
            Spacer()
        }
    }
}
