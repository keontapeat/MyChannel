//
//  BranchingNarrativeOverlay.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct BranchingNarrativeOverlay: View {
    @ObservedObject var interactiveService: InteractiveVideoService
    
    // In a real implementation this would trigger a seek on the actual player
    // var onSelectOption: ((BranchingOption) -> Void)?
    
    var body: some View {
        EmptyView()
    }
}

#Preview {
    BranchingNarrativeOverlay(interactiveService: InteractiveVideoService.shared)
}
