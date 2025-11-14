//
//  CastManager.swift
//  MyChannel
//
//  Optional Google Cast support with AirPlay fallback.
//

import Foundation
import AVKit
import SwiftUI

#if canImport(GoogleCast)
import GoogleCast
#endif

@MainActor
final class CastManager: ObservableObject {
    static let shared = CastManager()
    
    @Published var isCasting: Bool = false
    @Published var canCast: Bool = {
        #if canImport(GoogleCast)
        return true
        #else
        return false
        #endif
    }()
    
    private init() {
        #if canImport(GoogleCast)
        // If the host app configured GCKCastContext in AppDelegate, we're ready.
        _ = GCKCastContext.sharedInstance()
        #endif
    }
    
    func startCasting(video: Video) {
        #if canImport(GoogleCast)
        guard let url = URL(string: video.videoURL) else { return }
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(video.title, forKey: kGCKMetadataKeyTitle)
        
        let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: url)
        mediaInfoBuilder.streamType = .buffered
        mediaInfoBuilder.contentType = "video/mp4"
        mediaInfoBuilder.metadata = metadata
        
        let mediaInformation = mediaInfoBuilder.build()
        let request = GCKCastContext.sharedInstance().sessionManager.currentSession?.remoteMediaClient?.loadMedia(mediaInformation)
        isCasting = request != nil
        #endif
    }
    
    func stopCasting() {
        #if canImport(GoogleCast)
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
        isCasting = false
        #endif
    }
}

// MARK: - Cast Button (Chromecast or AirPlay fallback)
struct CastButton: View {
    let video: Video
    @StateObject private var cast = CastManager.shared
    
    var body: some View {
        Group {
            #if canImport(GoogleCast)
            CastUIKitButton(video: video)
                .frame(width: 32, height: 32)
            #else
            AirPlayRoutePickerView()
                .frame(width: 24, height: 24)
            #endif
        }
        .accessibilityLabel("Cast")
    }
}

#if canImport(GoogleCast)
import UIKit

struct CastUIKitButton: UIViewRepresentable {
    let video: Video
    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(type: .system)
        button.tintColor = UIColor.white
        return button
    }
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}
#endif


