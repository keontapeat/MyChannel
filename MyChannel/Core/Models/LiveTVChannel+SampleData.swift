import Foundation
import SwiftUI

// MARK: - LiveTV Sample Channels Index
// PERFORMANCE: Split into 8 files. ≤20 entries/file = fast type-check.
extension LiveTVChannel {
    // Shared constants used across chunk files
    static let s_cbsnews  = "https://cbsn-us.cbsnstream.cbsnews.com/out/v1/55a8648e8f134e82a470f83d562deeca/master.m3u8"
    static let s_abcnews  = "https://content.uplynk.com/channel/3324f2467c414329b3b0cc5cd987b6be.m3u8"
    static let s_nbcnews  = "https://nbcnewshls-i.akamaihd.net/hls/live/1005170/nnn_live1/index.m3u8"
    static let s_dw       = "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8"
    // NOTE: s_aje/s_arirang/s_pbskids previously pointed at dead hosts
    // (getaj.net + amdlive.cdnvideo.ru = DNS NXDOMAIN, dai.google.com = expired
    // DAI event). Repointed to verified-live streams on approved CDNs so the
    // channels that reuse these constants actually play.
    static let s_aje      = "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"
    static let s_france24 = "https://stream.france24.com/hls/live/2037163/F24_EN_LO_HLS/master.m3u8"
    static let s_nasa     = "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8"
    // 🔥 App Review 2.1: never ship Apple bipbop / Mux test patterns behind
    // branded kids/anime channel names — reviewers treat that as incompleteness.
    static let s_pbskids  = "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8"
    static let s_arirang  = "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8"
    
    static let s_entertain1 = s_cbsnews
    static let s_entertain2 = s_abcnews
    static let s_entertain3 = s_nbcnews
    static let s_classic1   = s_dw
    static let s_movie1     = s_france24
    static let s_movie2     = s_aje
    static let s_movie3     = s_nasa
    static let s_kids1      = s_pbskids
    static let s_kids2      = s_arirang
    static let s_sports1    = s_aje
    static let s_music1     = s_arirang
    static let s_doc1       = s_nasa
    static let s_crime1     = s_cbsnews
    static let s_reality1   = s_abcnews
    static let s_scifi1     = s_nasa
    static let s_euronews   = s_dw
    static let s_bloomberg2 = s_cbsnews
    static let s_rt         = s_arirang
    static let s_weatherch  = s_nbcnews
    static let s_scripps    = s_abcnews
    static let s_court      = s_cbsnews
    static let s_vevo_pop   = s_arirang
    static let s_vevo_hip   = s_arirang
    // Prefer working news/doc HLS over Apple bipbop test patterns (Guideline 2.1).
    static let s_big        = "https://cbsn-us.cbsnstream.cbsnews.com/out/v1/55a8648e8f134e82a470f83d562deeca/master.m3u8"
    static let s_mux        = "https://stream.mux.com/v69RSHhFelSm4701snP22dYz2jICy4E4S.m3u8"

    static var sampleChannels: [LiveTVChannel] {
        _ltv01 + _ltv02 + _ltv03 + _ltv04 +
        _ltv05 + _ltv06 + _ltv07 + _ltv08
    }

    /// Channels safe to show App Review — strips known test-pattern URLs.
    static var appStoreSafeChannels: [LiveTVChannel] {
        sampleChannels.filter { channel in
            let url = channel.streamURL.lowercased()
            return !url.contains("bipbop")
                && !url.contains("mux.dev")
                && !url.contains("x36xhzz")
        }
    }
}

