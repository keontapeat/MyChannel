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
    static let s_aje      = "https://live-hls-web-aje.getaj.net/AJE/index.m3u8"
    static let s_france24 = "https://stream.france24.com/hls/live/2037163/F24_EN_LO_HLS/master.m3u8"
    static let s_nasa     = "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8"
    static let s_pbskids  = "https://dai.google.com/linear/hls/event/Sid4xiWpT-iXi14bHkPH_g/master.m3u8"
    static let s_arirang  = "https://amdlive.cdnvideo.ru/arirang/live/arirangtv_eng/playlist.m3u8"
    
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
    static let s_big        = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    static let s_mux        = "https://stream.mux.com/v69RSHhFelSm4701snP22dYz2jICy4E4S.m3u8"

    static var sampleChannels: [LiveTVChannel] {
        _ltv01 + _ltv02 + _ltv03 + _ltv04 +
        _ltv05 + _ltv06 + _ltv07 + _ltv08
    }
}

