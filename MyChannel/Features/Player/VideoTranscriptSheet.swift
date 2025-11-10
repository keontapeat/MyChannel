import SwiftUI

struct VideoTranscriptSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLanguage = "English"
    @State private var autoScroll = true
    @State private var currentTime: TimeInterval = 0
    
    private let languages = ["English", "Spanish", "French", "German", "Japanese", "Korean"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Language Controls
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search transcript...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Language:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Spacer()
                        
                        Toggle("Auto-scroll", isOn: $autoScroll)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Transcript Content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(mockTranscriptSegments, id: \.id) { segment in
                            TranscriptSegmentView(
                                segment: segment,
                                searchText: searchText,
                                isHighlighted: abs(segment.startTime - currentTime) < 2.0
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Download Transcript") {
                            // Handle download
                        }
                        Button("Copy All Text") {
                            // Handle copy
                        }
                        Button("Report Issue") {
                            // Handle report
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private var mockTranscriptSegments: [VideoTranscriptSegment] {
        [
            VideoTranscriptSegment(id: "1", startTime: 0, endTime: 5, text: "Welcome to this amazing video tutorial where we'll explore the latest features in iOS development."),
            VideoTranscriptSegment(id: "2", startTime: 5, endTime: 12, text: "Today we're going to dive deep into SwiftUI and learn how to create beautiful, responsive user interfaces."),
            VideoTranscriptSegment(id: "3", startTime: 12, endTime: 18, text: "First, let's start by understanding the basic concepts of declarative programming in SwiftUI."),
            VideoTranscriptSegment(id: "4", startTime: 18, endTime: 25, text: "SwiftUI allows us to describe our user interface using a simple, intuitive syntax that's easy to read and maintain."),
            VideoTranscriptSegment(id: "5", startTime: 25, endTime: 32, text: "One of the key advantages of SwiftUI is its ability to automatically handle state management and view updates.")
        ]
    }
}

struct VideoTranscriptSegment: Identifiable {
    let id: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct TranscriptSegmentView: View {
    let segment: VideoTranscriptSegment
    let searchText: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(segment.startTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHighlighted ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    )
                
                if isHighlighted {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .padding(.leading, 12)
                }
            }
            
            // Text content
            Text(highlightedText)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
                .background(
                    isHighlighted ? 
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .padding(.horizontal, -8)
                        .padding(.vertical, -4)
                    : nil
                )
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Seek to this timestamp
            NotificationCenter.default.post(
                name: NSNotification.Name("SeekToTimestamp"),
                object: segment.startTime
            )
        }
    }
    
    private var highlightedText: AttributedString {
        var attributedString = AttributedString(segment.text)
        
        if !searchText.isEmpty {
            let ranges = segment.text.ranges(of: searchText, options: .caseInsensitive)
            for range in ranges {
                let start = AttributedString.Index(range.lowerBound, within: attributedString)!
                let end = AttributedString.Index(range.upperBound, within: attributedString)!
                attributedString[start..<end].backgroundColor = .yellow
                attributedString[start..<end].foregroundColor = .black
            }
        }
        
        return attributedString
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex
        
        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }
        
        return ranges
    }
}

#Preview {
    VideoTranscriptSheet(video: Video.sampleVideos[0])
}

