//
//  ContentBulkEditView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct ContentBulkEditView: View {
    @State private var videos: [Video] = Array(Video.sampleVideos.prefix(12))
    @State private var selected: Set<String> = []
    @State private var newVisibility: Visibility = .public
    @State private var scheduleDate: Date = Date().addingTimeInterval(3600)
    @State private var tagsInput: String = ""
    
    enum Visibility: String, CaseIterable, Identifiable { case `public`, unlisted, `private`; var id: String { rawValue } }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Select videos") {
                    ForEach(videos) { v in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selected.contains(v.id) },
                                set: { isOn in
                                    var copy = selected
                                    if isOn { copy.insert(v.id) } else { copy.remove(v.id) }
                                    selected = copy
                                }
                            )) { EmptyView() }
                            .labelsHidden()
                            
                            Text(v.title).lineLimit(1)
                        }
                    }
                }
                Section("Bulk actions") {
                    Picker("Visibility", selection: $newVisibility) {
                        ForEach(Visibility.allCases) { v in Text(v.rawValue.capitalized).tag(v) }
                    }
                    DatePicker("Schedule publish", selection: $scheduleDate)
                    TextField("Add tags (comma separated)", text: $tagsInput)
                    Button("Apply to Selected") { apply() }
                        .disabled(selected.isEmpty)
                }
            }
        }
        .navigationTitle("Bulk Edit")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func apply() {
        let tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        videos = videos.map { v in
            guard selected.contains(v.id) else { return v }
            var updated = v
            updated.tags = Array(Set(updated.tags + tags))
            return updated
        }
        // NOTE: In a real app, call an API to update visibility and schedule
    }
}

#Preview {
    NavigationStack { ContentBulkEditView() }
}


