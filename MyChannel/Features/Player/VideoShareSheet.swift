import SwiftUI

import SwiftUI

struct VideoShareSheet: View {
    let items: [Any]
    
    var body: some View {
        VStack {
            Text("Share Sheet")
                .font(.title)
            
            Text("Items to share: \(items.count)")
            
            ForEach(0..<items.count, id: \.self) { index in
                Text("\(items[index])")
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    VideoShareSheet(items: ["https://example.com/video1.mp4", "Sample Video"])
}
