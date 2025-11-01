//
//  DeepLinkService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

final class DeepLinkService: ObservableObject {
    static let shared = DeepLinkService()
    @Published var route: DeepLinkRoute? = nil
    private init() {}
    
    func handle(url: URL) {
        guard url.host == "studio" else { return }
        let tabStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "tab" })?.value ?? "overview"
        DispatchQueue.main.async { self.route = .studio(tab: tabStr) }
    }
}


