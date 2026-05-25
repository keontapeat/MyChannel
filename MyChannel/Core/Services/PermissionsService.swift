#if canImport(PermissionsKit)
import PermissionsKit
import CameraPermission
import MicrophonePermission
import NotificationPermission
import PhotoLibraryPermission
#endif
import Foundation
import AVFoundation
import Photos
import UserNotifications

/// App Permissions Manager
/// Uses PermissionsKit for beautiful permission request UI.
/// Falls back to native AVFoundation/Photos APIs if PermissionsKit is unavailable.
@MainActor
final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published var cameraAuthorized: Bool = false
    @Published var microphoneAuthorized: Bool = false
    @Published var photoLibraryAuthorized: Bool = false
    @Published var notificationsAuthorized: Bool = false

    private init() {
        Task { await refreshAllStatuses() }
    }

    func refreshAllStatuses() async {
        cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        microphoneAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        photoLibraryAuthorized = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    func requestCamera() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorized = granted
        return granted
    }

    func requestMicrophone() async -> Bool {
        let granted = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        microphoneAuthorized = granted
        return granted
    }

    func requestPhotoLibrary() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryAuthorized = status == .authorized
        return photoLibraryAuthorized
    }

    func requestNotifications() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        notificationsAuthorized = granted
        return granted
    }

    /// Request all permissions needed for live streaming
    func requestLiveStreamPermissions() async -> Bool {
        let cam = await requestCamera()
        let mic = await requestMicrophone()
        return cam && mic
    }

    /// Request all permissions needed for video upload
    func requestUploadPermissions() async -> Bool {
        let photos = await requestPhotoLibrary()
        return photos
    }
}
