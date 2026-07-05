import SwiftUI
import UIKit

struct VideoTranscriptSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchFocused = false
    @State private var selectedLanguage = "English"
    @State private var autoScroll = true
    @State private var currentTime: TimeInterval = 0
    @State private var segments: [VideoTranscriptSegment] = []
    @State private var isLoading = true
    @State private var shareText: String?

    private var languages: [String] {
        let subs = (video.subtitles ?? []).map { $0.language }
        return subs.isEmpty ? ["English"] : Array(Set(subs)).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Language Controls
                VStack(spacing: 12) {
                    HStack {
                        UIKitSearchBar(
                            text: $searchText,
                            placeholder: "Search transcript...",
                            isFirstResponder: searchFocused,
                            onFocusChanged: { focused in
                                searchFocused = focused
                            }
                        )
                        .frame(height: 44)
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
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if segments.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "captions.bubble")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Transcript not available")
                                .font(.system(size: 16, weight: .semibold))
                            Text("This video doesn't have captions yet.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(segments, id: \.id) { segment in
                                TranscriptSegmentView(
                                    segment: segment,
                                    searchText: searchText,
                                    isHighlighted: abs(segment.startTime - currentTime) < 2.0
                                )
                            }
                        }
                        .padding()
                    }
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
                        Button {
                            shareText = transcriptPlainText()
                        } label: {
                            Label("Download Transcript", systemImage: "square.and.arrow.down")
                        }
                        .disabled(segments.isEmpty)

                        Button {
                            UIPasteboard.general.string = transcriptPlainText()
                            HapticManager.shared.notification(type: .success)
                        } label: {
                            Label("Copy All Text", systemImage: "doc.on.doc")
                        }
                        .disabled(segments.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await loadTranscript() }
            .onChange(of: selectedLanguage) { _ in Task { await loadTranscript() } }
            .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
                if let text = shareText {
                    NativeShareSheet(items: [text])
                }
            }
        }
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.medium(), .large()],
                    largestUndimmedDetentIdentifier: .large,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: false,
                    preferredCornerRadius: 28
                )
            )
        )
    }
    
    private func transcriptPlainText() -> String {
        segments.map { "[\(formatTimecode($0.startTime))] \($0.text)" }.joined(separator: "\n")
    }

    private func formatTimecode(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Real transcript loading (from the video's subtitle track)

    private func loadTranscript() async {
        isLoading = true
        let tracks = video.subtitles ?? []
        // Prefer the selected language, then the default track, then the first.
        let track = tracks.first(where: { $0.language == selectedLanguage })
            ?? tracks.first(where: { $0.isDefault })
            ?? tracks.first
        guard let track, let url = URL(string: track.url) else {
            segments = []
            isLoading = false
            return
        }
        let parsed = await Self.fetchAndParseVTT(url: url)
        segments = parsed
        isLoading = false
    }

    private static func fetchAndParseVTT(url: URL) async -> [VideoTranscriptSegment] {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return parseVTT(text)
    }

    private static func parseVTT(_ text: String) -> [VideoTranscriptSegment] {
        var result: [VideoTranscriptSegment] = []
        let blocks = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.split(separator: "\n").map(String.init)
            guard let arrowLine = lines.first(where: { $0.contains("-->") }) else { continue }
            let parts = arrowLine.components(separatedBy: "-->")
            guard parts.count == 2 else { continue }
            let start = parseTimecode(parts[0])
            let end = parseTimecode(parts[1].split(separator: " ").first.map(String.init) ?? parts[1])
            guard let arrowIdx = lines.firstIndex(of: arrowLine) else { continue }
            let textLines = Array(lines[(arrowIdx + 1)...])
            let cueText = textLines.joined(separator: " ")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if !cueText.isEmpty {
                result.append(VideoTranscriptSegment(id: "\(result.count)", startTime: start, endTime: end.isNaN ? start + 4 : end, text: cueText))
            }
        }
        return result
    }

    /// Parses "HH:MM:SS.mmm" or "MM:SS.mmm" into seconds.
    private static func parseTimecode(_ raw: String) -> TimeInterval {
        let clean = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let comps = clean.split(separator: ":").map { Double($0) ?? 0 }
        switch comps.count {
        case 3: return comps[0] * 3600 + comps[1] * 60 + comps[2]
        case 2: return comps[0] * 60 + comps[1]
        default: return Double(clean) ?? 0
        }
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

