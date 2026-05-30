// ⚡ PERFORMANCE: Extracted from UploadView.swift — independent compilation unit.
// New YouTube parity components and ImagePicker compile in parallel.
import SwiftUI
import PhotosUI

// MARK: - New YouTube Parity Components

// MARK: - Visibility Picker (Disabled - using simple toggle instead)
/*
*/



// MARK: - ImagePicker Wrapper


#Preview("UploadView") {
    UploadView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}