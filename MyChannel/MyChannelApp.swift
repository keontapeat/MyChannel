//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta  on 7/9/25.
//

import SwiftUI

@main
struct MyChannelApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
    }
}