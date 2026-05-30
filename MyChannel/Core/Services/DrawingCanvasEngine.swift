import Foundation
import PencilKit
import FirebaseFirestore
import Combine

/// Phase 72: Real-time Multi-user Drawing Canvas
/// Syncs PencilKit vector strokes via Firestore for collaborative whiteboard sessions over paused video frames.
@MainActor
final class DrawingCanvasEngine: ObservableObject {
    static let shared = DrawingCanvasEngine()
    private let db = Firestore.firestore()
    
    @Published var currentDrawing = PKDrawing()
    private var listener: ListenerRegistration?
    private var activeRoomId: String?
    
    // Throttle saves to prevent Firestore rate limits
    private var isSaving = false
    private var pendingSave = false
    
    private init() {}
    
    /// Connects to a collaborative drawing room (usually tied to a video ID)
    func connectToRoom(_ roomId: String) {
        self.activeRoomId = roomId
        listener?.remove()
        
        let docRef = db.collection("drawingRooms").document(roomId)
        
        listener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data(), let base64Data = data["drawingData"] as? String else {
                return
            }
            
            // Avoid overwriting our own drawing while we are currently saving
            guard !self.isSaving else { return }
            
            if let decodedData = Data(base64Encoded: base64Data) {
                do {
                    let incomingDrawing = try PKDrawing(data: decodedData)
                    self.currentDrawing = incomingDrawing
                } catch {
                    print("⚠️ [DrawingCanvas] Failed to decode incoming drawing: \(error)")
                }
            }
        }
    }
    
    func disconnect() {
        listener?.remove()
        listener = nil
        activeRoomId = nil
        currentDrawing = PKDrawing()
    }
    
    /// Called when the user lifts their Apple Pencil or finger
    func pushDrawing(_ drawing: PKDrawing) {
        guard let roomId = activeRoomId else { return }
        
        self.currentDrawing = drawing
        
        guard !isSaving else {
            pendingSave = true
            return
        }
        
        performSave(drawing: drawing, roomId: roomId)
    }
    
    private func performSave(drawing: PKDrawing, roomId: String) {
        isSaving = true
        pendingSave = false
        
        let base64Data = drawing.dataRepresentation().base64EncodedString()
        let docRef = db.collection("drawingRooms").document(roomId)
        
        docRef.setData([
            "drawingData": base64Data,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true) { [weak self] error in
            guard let self = self else { return }
            self.isSaving = false
            
            if let error = error {
                print("⚠️ [DrawingCanvas] Failed to save drawing: \(error)")
            } else {
                if self.pendingSave {
                    self.performSave(drawing: self.currentDrawing, roomId: roomId)
                }
            }
        }
    }
    
    func clearCanvas() {
        pushDrawing(PKDrawing())
    }
}
