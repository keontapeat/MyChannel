import WidgetKit
import SwiftUI

/// Phase 91: WidgetKit Home Screen Widgets
/// A TimelineProvider that fetches the top trending video thumbnail for the home screen widget.

struct VideoEntry: TimelineEntry {
    let date: Date
    let videoTitle: String
    let thumbnailData: Data?
}

struct FeaturedVideoProvider: TimelineProvider {
    func placeholder(in context: Context) -> VideoEntry {
        VideoEntry(date: Date(), videoTitle: "Trending Video", thumbnailData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (VideoEntry) -> ()) {
        let entry = VideoEntry(date: Date(), videoTitle: "Top Trending Video", thumbnailData: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // In a real app, this fetches from CloudKit/Firestore REST API or shared App Group UserDefaults
        let entry = VideoEntry(date: Date(), videoTitle: "Live Now: The Grand Final", thumbnailData: nil)
        
        // Refresh every 30 minutes
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct FeaturedVideoWidgetEntryView : View {
    var entry: FeaturedVideoProvider.Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = entry.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
            
            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
            
            Text(entry.videoTitle)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
        }
        .widgetURL(URL(string: "mychannel://watch?v=trending"))
    }
}

// @main
struct FeaturedVideoWidget: Widget {
    let kind: String = "FeaturedVideoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FeaturedVideoProvider()) { entry in
            FeaturedVideoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Featured Video")
        .description("See the top trending video right on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
