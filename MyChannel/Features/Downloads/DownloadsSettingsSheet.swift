//
//  DownloadsSettingsSheet.swift
//  MyChannel
//
//  Download settings sheet extracted from DownloadsView (>900 LOC).
//

import SwiftUI

struct DownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var offlineService = OfflineDownloadService.shared
    @State private var downloadQuality: DownloadQuality = .high
    @State private var wifiOnly = true
    @State private var autoDelete = false
    @State private var storageLimit = 10.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Form {
                    Section {
                        Picker("Download quality", selection: $downloadQuality) {
                            Text("Low (360p)").tag(DownloadQuality.low)
                            Text("Medium (480p)").tag(DownloadQuality.medium)
                            Text("High (720p)").tag(DownloadQuality.high)
                            Text("HD (1080p)").tag(DownloadQuality.hd)
                        }
                    } header: {
                        Text("Quality")
                    } footer: {
                        Text("Higher quality uses more storage")
                    }

                    Section {
                        Toggle("Download over Wi-Fi only", isOn: $wifiOnly)
                        Toggle("Auto-delete watched videos", isOn: $autoDelete)
                    } header: {
                        Text("Downloads")
                    } footer: {
                        Text("Wi-Fi only avoids data charges. Auto-delete frees space by removing videos after you finish them.")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Storage limit: \(Int(storageLimit)) GB")
                                .font(.system(size: 15))
                                .foregroundColor(.white)

                            Slider(value: $storageLimit, in: 1...50, step: 1)
                                .tint(.blue)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Storage limit")
                    } footer: {
                        Text("Downloads pause when your offline library reaches this size.")
                    }

                    Section {
                        HStack {
                            Text("Total storage used")
                                .foregroundColor(.white)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: offlineService.usedStorage, countStyle: .file))
                                .foregroundColor(.gray)
                        }
                    }

                    Section {
                        Button("Delete all downloads") {
                            Task {
                                await offlineService.deleteAllDownloads()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Download Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .task {
                downloadQuality = offlineService.downloadQuality
                wifiOnly = offlineService.downloadOnlyOnWiFi
                autoDelete = offlineService.autoDeleteWatchedVideos
                storageLimit = Double(offlineService.maxStorageLimit) / 1_000_000_000.0
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        offlineService.downloadQuality = downloadQuality
                        offlineService.downloadOnlyOnWiFi = wifiOnly
                        offlineService.autoDeleteWatchedVideos = autoDelete
                        offlineService.maxStorageLimit = Int64(storageLimit * 1_000_000_000.0)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    DownloadSettingsView()
}
