import SwiftUI
import AVKit

/// On-Device Video Trimmer and Compressor using FFmpegKit
struct FFmpegTrimmerView: View {
    @State private var inputVideoURL: URL?
    @State private var isCompressing: Bool = false
    @State private var compressionSuccess: Bool = false
    @State private var compressionProgress: Double = 0.0
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Shorts On-Device Editor")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            if let videoURL = inputVideoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding()
                
                if isCompressing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        Text("Compressing to 720p via FFmpeg...")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if compressionSuccess {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("Ready for Lightning Fast Upload!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    
                    Button("Continue to Upload") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Button(action: compressVideo) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Auto-Optimize & Compress")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            } else {
                Button(action: selectVideo) {
                    VStack {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Select Raw Video")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                .padding()
            }
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Trimmer")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectVideo() {
        // In a real app, you would use PhotosPicker.
        // For scaffolding, we mock a local URL selection.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("raw_sample.mp4")
        self.inputVideoURL = tempURL
    }
    
    private func compressVideo() {
        guard let inputURL = inputVideoURL else { return }
        
        isCompressing = true
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("compressed_shorts.mp4")
        
        Task {
            let success = try? await VideoEditorFFmpegService.shared.compressVideoForWeb(inputURL: inputURL, outputURL: outputURL)
            
            DispatchQueue.main.async {
                self.isCompressing = false
                if success == true {
                    self.compressionSuccess = true
                    // Now `outputURL` is the crushed 720p file ready to upload to Firebase Storage!
                }
            }
        }
    }
}
