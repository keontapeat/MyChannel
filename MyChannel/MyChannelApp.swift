//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta  on 7/9/25.
//

import SwiftUI

@main
struct MyChannelApp: App {
    @State private var showingSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showingSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingSplash = false
                    }
                }
            } else {
                MainTabView()
            }
        }
    }
}