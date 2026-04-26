import SwiftUI

struct CreatePostView: View {
    let creator: User

    var body: some View {
        CreateCommunityPostView(creator: creator)
    }
}

#Preview {
    CreatePostView(creator: User.sampleUsers[0])
}

