import Foundation
import CoreLocation
import MapKit
import FirebaseFirestore
import Combine

/// Phase 81: Live Location Map Tracking
/// Integrates CoreLocation to broadcast streamer GPS coords to Firestore, and MapKit to render them.
@MainActor
final class LiveLocationEngine: NSObject, ObservableObject {
    static let shared = LiveLocationEngine()
    private let db = Firestore.firestore()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var streamerLocation: CLLocationCoordinate2D?
    
    private var isBroadcasting = false
    private var activeStreamId: String?
    private var listener: ListenerRegistration?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Starts broadcasting the user's location to a live stream document in Firestore
    func startBroadcasting(streamId: String) {
        self.activeStreamId = streamId
        self.isBroadcasting = true
        locationManager.startUpdatingLocation()
        print("📍 [LiveLocation] Started broadcasting location for stream \(streamId)")
    }
    
    func stopBroadcasting() {
        self.isBroadcasting = false
        self.activeStreamId = nil
        locationManager.stopUpdatingLocation()
        print("📍 [LiveLocation] Stopped broadcasting location.")
    }
    
    /// Listens to another streamer's location in real-time
    func listenToStreamerLocation(streamId: String) {
        listener?.remove()
        
        let docRef = db.collection("live_streams").document(streamId)
        listener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let data = snapshot?.data(),
                  let lat = data["latitude"] as? Double,
                  let lon = data["longitude"] as? Double else { return }
            
            self?.streamerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        print("📡 [LiveLocation] Listening to streamer location for \(streamId)")
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        streamerLocation = nil
    }
}

extension LiveLocationEngine: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location.coordinate
            
            if self.isBroadcasting, let streamId = self.activeStreamId {
                self.db.collection("live_streams").document(streamId).setData([
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "locationUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ [LiveLocation] CoreLocation failed: \(error)")
    }
}
