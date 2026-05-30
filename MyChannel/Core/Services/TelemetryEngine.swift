import Foundation
import MetricKit
import FirebaseFirestore

/// Phase 87: MetricKit App Telemetry
/// Automatically logs power, performance, and crash metrics from MXMetricManager to Firestore.
@MainActor
final class TelemetryEngine: NSObject, ObservableObject {
    static let shared = TelemetryEngine()
    private let db = Firestore.firestore()
    
    private override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }
    
    deinit {
        MXMetricManager.shared.remove(self)
    }
    
    /// Called manually to track specific custom checkpoints (e.g. video load time)
    func trackSignpost(name: StaticString) {
        if #available(iOS 14.0, *) {
            mxSignpost(.event, log: .default, name: name)
        }
    }
}

extension TelemetryEngine: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        guard let payload = payloads.last else { return }
        
        Task { @MainActor in
            var telemetryData: [String: Any] = [
                "timestamp": FieldValue.serverTimestamp(),
                "appVersion": payload.latestApplicationVersion,
                "osVersion": payload.metaData?.osVersion ?? "Unknown",
                "deviceType": payload.metaData?.deviceType ?? "Unknown"
            ]
            
            // Extract cellular conditions
            if let cellular = payload.cellularConditionMetrics {
                telemetryData["cellularBars"] = cellular.histogrammedCellularConditionTime.totalBucketCount
            }
            
            // Extract performance metrics
            if let signposts = payload.signpostMetrics {
                telemetryData["signpostCount"] = signposts.reduce(0) { $0 + $1.totalCount }
            }
            
            // Extract CPU/GPU time
            if let cpu = payload.cpuMetrics {
                telemetryData["cpuTimeSeconds"] = cpu.cumulativeCPUTime.value
            }
            
            do {
                try await db.collection("telemetry_logs").addDocument(data: telemetryData)
                print("📊 [Telemetry] Uploaded MetricKit payload to Firestore.")
            } catch {
                print("⚠️ [Telemetry] Failed to upload metrics: \(error)")
            }
        }
    }
    
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let payload = payloads.last else { return }
        
        Task { @MainActor in
            print("🚨 [Telemetry] Received Diagnostic Payload (Crashes/Hangs).")
            
            if let crashes = payload.crashDiagnostics {
                for crash in crashes {
                    db.collection("crash_reports").addDocument(data: [
                        "timestamp": FieldValue.serverTimestamp(),
                        "reason": crash.terminationReason ?? "Unknown",
                        "callStack": crash.callStackTree.jsonRepresentation().base64EncodedString()
                    ])
                }
            }
        }
    }
}
