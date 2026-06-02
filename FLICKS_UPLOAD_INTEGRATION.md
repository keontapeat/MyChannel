# 🚀 Flicks Upload Integration Guide

Quick guide to integrate the new `saveFlick()` API into your upload flows.

## iOS (Swift) - FlicksStudioView

### Location: `MyChannel/Features/Studio/Views/FlicksStudioView.swift`

### Before (Line 176-183):
```swift
private func loadFlicks() {
    // Load user's Flicks (short videos)
    Task {
        // Filter for videos under 60 seconds
        flicks = [] // TODO: Load from Firestore where duration < 60
        isLoading = false
    }
}
```

### After (Complete Implementation):
```swift
private func loadFlicks() {
    Task {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseFirestore)
        guard let currentUserId = AppState.shared.currentUser?.id else {
            flicks = []
            return
        }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("flicks")
                .whereField("creatorId", isEqualTo: currentUserId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            flicks = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let videoURL = d["videoUrl"] as? String ?? d["videoURL"] as? String,
                      let thumbnailURL = d["thumbnailUrl"] as? String ?? d["thumbnailURL"] as? String else {
                    return nil
                }
                
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: thumbnailURL,
                    videoURL: videoURL,
                    duration: d["duration"] as? Double ?? 0,
                    viewCount: d["viewCount"] as? Int ?? 0,
                    likeCount: d["likeCount"] as? Int ?? 0,
                    commentCount: d["commentCount"] as? Int ?? 0,
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .shorts,
                    tags: d["tags"] as? [String] ?? [],
                    isPublic: true,
                    quality: [.quality720p],
                    aspectRatio: .portrait,
                    isLiveStream: false,
                    contentSource: .userUploaded,
                    isVerified: false
                )
            }
            
            print("✅ [FlicksStudio] Loaded \(flicks.count) user Flicks")
        } catch {
            print("🚨 [FlicksStudio] Error loading Flicks: \(error)")
            flicks = []
        }
        #else
        flicks = []
        #endif
    }
}
```

### Add Upload Handler (New Method):
```swift
/// Upload a Flick to Firestore
private func uploadFlick(
    videoFile: URL,
    title: String,
    description: String,
    tags: [String],
    musicTrack: (title: String, artist: String)? = nil
) async throws {
    guard let currentUser = AppState.shared.currentUser else {
        throw FlickUploadError.notAuthenticated
    }
    
    // 1. Generate Flick ID
    let flickId = UUID().uuidString
    
    // 2. Upload video to Storage
    let videoData = try Data(contentsOf: videoFile)
    let storageRef = Storage.storage().reference().child("flicks/\(currentUser.id)/\(flickId).mp4")
    let metadata = StorageMetadata()
    metadata.contentType = "video/mp4"
    
    _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
    let videoURL = try await storageRef.downloadURL().absoluteString
    
    // 3. Generate thumbnail (from first frame)
    let thumbnailURL = try await generateThumbnail(from: videoFile, flickId: flickId)
    
    // 4. Get video duration
    let asset = AVAsset(url: videoFile)
    let duration = try await asset.load(.duration).seconds
    
    // 5. Save to Firestore
    let savedFlickId = try await ShortsFirestoreService.shared.saveFlick(
        id: flickId,
        title: title,
        description: description,
        videoURL: videoURL,
        thumbnailURL: thumbnailURL,
        duration: duration,
        tags: tags,
        musicTrack: musicTrack,
        userId: currentUser.id,
        username: currentUser.username,
        userDisplayName: currentUser.displayName,
        userProfileImageURL: currentUser.profileImageURL ?? "",
        userIsVerified: currentUser.isVerified
    )
    
    print("✅ [FlicksStudio] Uploaded Flick: \(savedFlickId)")
    
    // 6. Reload Flicks list
    loadFlicks()
}

/// Generate thumbnail from video
private func generateThumbnail(from videoURL: URL, flickId: String) async throws -> String {
    let asset = AVAsset(url: videoURL)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    // Get frame at 1 second
    let time = CMTime(seconds: 1, preferredTimescale: 600)
    let cgImage = try await imageGenerator.image(at: time).image
    let uiImage = UIImage(cgImage: cgImage)
    
    // Convert to JPEG data
    guard let thumbnailData = uiImage.jpegData(compressionQuality: 0.8) else {
        throw FlickUploadError.thumbnailGenerationFailed
    }
    
    // Upload thumbnail to Storage
    guard let currentUser = AppState.shared.currentUser else {
        throw FlickUploadError.notAuthenticated
    }
    
    let storageRef = Storage.storage().reference().child("flicks/\(currentUser.id)/thumbnails/\(flickId).jpg")
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    _ = try await storageRef.putDataAsync(thumbnailData, metadata: metadata)
    let thumbnailURL = try await storageRef.downloadURL().absoluteString
    
    return thumbnailURL
}

enum FlickUploadError: LocalizedError {
    case notAuthenticated
    case thumbnailGenerationFailed
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        case .thumbnailGenerationFailed: return "Failed to generate thumbnail"
        case .uploadFailed: return "Upload failed"
        }
    }
}
```

### Update FlickUploadSheet (New Implementation):
```swift
struct FlickUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onFlickCreated: (Video) -> Void
    
    @State private var selectedVideo: URL?
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var tags: [String] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Video") {
                    Button("Select Video") {
                        // Show video picker
                    }
                    if let video = selectedVideo {
                        Text(video.lastPathComponent)
                    }
                }
                
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Tags") {
                    // Add tag input
                }
                
                Section {
                    Button(action: uploadFlick) {
                        if isUploading {
                            HStack {
                                ProgressView(value: uploadProgress)
                                Text("\(Int(uploadProgress * 100))%")
                            }
                        } else {
                            Text("Upload Flick")
                        }
                    }
                    .disabled(selectedVideo == nil || title.isEmpty || isUploading)
                }
            }
            .navigationTitle("New Flick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func uploadFlick() {
        guard let videoURL = selectedVideo else { return }
        
        isUploading = true
        
        Task {
            do {
                try await uploadFlickToFirestore(
                    videoFile: videoURL,
                    title: title,
                    description: description,
                    tags: tags
                )
                
                // Success!
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("🚨 Upload error: \(error)")
                isUploading = false
            }
        }
    }
    
    private func uploadFlickToFirestore(...) async throws {
        // Use the uploadFlick method from above
    }
}
```

---

## Web (Next.js/TypeScript)

### Location: `web-v2/app/flicks/upload/page.tsx`

### Before (Line 94-102):
```typescript
// TODO: Save Flick metadata to Firestore
console.log('Flick uploaded:', {
  flickId,
  title,
  description,
  tags,
  musicTrack,
  videoURL,
});
```

### After (Complete Implementation):
```typescript
// ✅ Save Flick metadata to Firestore
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

const flickRef = await addDoc(collection(db, 'flicks'), {
  title: title,
  description: description,
  videoUrl: videoURL,
  thumbnailUrl: videoURL.replace('.mp4', '_thumb.jpg'), // Or generate thumbnail
  duration: videoDuration, // Get from video metadata
  viewCount: 0,
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  creatorId: auth.currentUser?.uid || 'unknown',
  creatorUsername: auth.currentUser?.displayName || 'User',
  creatorDisplayName: auth.currentUser?.displayName || 'User',
  creatorProfileImage: auth.currentUser?.photoURL || '',
  creatorIsVerified: false,
  tags: tags,
  musicTrack: musicTrack ? {
    title: musicTrack,
    artist: 'Unknown'
  } : null,
  aspectRatio: 'portrait',
  isPublic: true,
  category: 'shorts'
});

console.log('✅ Flick saved to Firestore:', flickRef.id);
```

### Add Thumbnail Generation (Optional):
```typescript
// Generate thumbnail from video (first frame)
async function generateThumbnail(videoFile: File): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    
    video.onloadeddata = () => {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx?.drawImage(video, 0, 0);
      
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error('Thumbnail generation failed'));
      }, 'image/jpeg', 0.8);
    };
    
    video.onerror = reject;
    video.src = URL.createObjectURL(videoFile);
  });
}

// Usage:
const thumbnailBlob = await generateThumbnail(videoFile);
const thumbnailURL = await StorageService.uploadThumbnail(thumbnailBlob, flickId);
```

---

## Testing Checklist

### iOS
- [ ] Can upload video from photo library
- [ ] Title and description are saved correctly
- [ ] Tags are saved correctly
- [ ] Thumbnail is generated automatically
- [ ] Video duration is calculated correctly
- [ ] Flick appears in FlicksStudioView after upload
- [ ] Flick appears in main Flicks feed
- [ ] Engagement tracking works (likes, views, comments)

### Web
- [ ] Can upload video file
- [ ] Title and description are saved correctly
- [ ] Tags are saved correctly
- [ ] Video plays in Flicks feed
- [ ] Creator info is displayed correctly
- [ ] Engagement buttons work

---

## Quick Test

### iOS:
```swift
// In your app delegate or a test view:
Task {
    // Add sample Flicks
    await AddSampleFlicks.addSamples()
    
    // Or test upload:
    // 1. Go to Studio → Flicks → Create Flick
    // 2. Select video from library
    // 3. Add title and description
    // 4. Tap "Upload Flick"
    // 5. Check Flicks feed - should appear!
}
```

### Web:
```bash
# Navigate to:
http://localhost:3000/flicks/upload

# 1. Select video file
# 2. Add title and description
# 3. Click "Upload Flick"
# 4. Navigate to /flicks - should appear!
```

---

## Common Issues

### Issue: "Firebase not initialized"
**Solution:** Ensure Firebase is configured in `AppDelegate` (iOS) or `firebase/config.ts` (Web)

### Issue: "Permission denied"
**Solution:** Update Firestore security rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /shorts/{flickId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Issue: "Storage upload fails"
**Solution:** Update Firebase Storage rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /flicks/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Issue: "Video duration is 0"
**Solution:** Make sure to await `asset.load(.duration)` before saving

---

## Need Help?

Check these files for complete implementations:
- ✅ `MyChannel/Core/Services/ShortsFirestoreService.swift` - Upload API
- ✅ `MyChannel/Scripts/AddSampleFlicks.swift` - Sample data
- ✅ `FLICKS_FIX_SUMMARY.md` - Complete fix summary

**Happy coding! 🚀**





