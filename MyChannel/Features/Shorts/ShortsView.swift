//
//  ShortsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ShortsView: View {
    var body: some View {
        VerticalShortsView()
            .navigationBarHidden(true)
            .ignoresSafeArea(.all)
    }
}

#Preview {
    ShortsView()
}