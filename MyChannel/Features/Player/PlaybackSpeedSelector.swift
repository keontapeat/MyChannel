import SwiftUI
import AVKit

import SwiftUI

struct PlaybackSpeedSelector: View {
    @Binding var selectedSpeed: Float
    let onSpeedSelected: (Float) -> Void
    
    let speeds: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Playback Speed")
                    .font(.title)
                    .bold()
                
                List(speeds, id: \.self) { speed in
                    Button(action: {
                        selectedSpeed = speed
                        onSpeedSelected(speed)
                        dismiss()
                    }) {
                        HStack {
                            Text("\(speed)x")
                            Spacer()
                            if speed == selectedSpeed {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Speed")
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
    PlaybackSpeedSelector(
        selectedSpeed: .constant(1.0),
        onSpeedSelected: { _ in }
    )
}
