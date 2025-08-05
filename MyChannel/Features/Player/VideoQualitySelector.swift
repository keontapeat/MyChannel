import SwiftUI

import SwiftUI

struct VideoQualitySelector: View {
    @Binding var selectedQuality: VideoQuality
    let onQualitySelected: (VideoQuality) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Video Quality")
                    .font(.title)
                    .bold()
                
                List(VideoQuality.allCases, id: \.self) { quality in
                    Button(action: {
                        selectedQuality = quality
                        onQualitySelected(quality)
                        dismiss()
                    }) {
                        HStack {
                            Text(quality.displayName)
                            Spacer()
                            if quality == selectedQuality {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VideoQualitySelector(
        selectedQuality: .constant(.auto),
        onQualitySelected: { _ in }
    )
}
