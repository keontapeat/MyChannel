//
//  CrossDepartmentIntelService.swift
//  MyChannel
//
//  Phase 890: Cross-Department Intelligence Hub
//  Department health correlation, dependency mapping, bottleneck detection
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CrossDepartmentIntelService: ObservableObject {
    static let shared = CrossDepartmentIntelService()

    // MARK: - Domain Models

    struct DepartmentHealth: Identifiable, Codable {
        let id: String
        let department: String
        let healthScore: Double
        let activeTasks: Int
        let completedTasks24h: Int
        let avgResponseTimeMinutes: Double
        let slaCompliance: Double
        let staffingLevel: String
        let topBlocker: String?
    }

    struct DependencyMap: Identifiable, Codable {
        let id: String
        let source: String
        let target: String
        let dependencyType: String
        let strength: Double
        let latencyMs: Int
        let errorRate: Double
    }

    struct Bottleneck: Identifiable, Codable {
        let id: String
        let department: String
        let process: String
        let avgDelayMinutes: Double
        let affectedWorkflows: Int
        let rootCause: String
        let recommendation: String
        let severity: String
    }

    struct PriorityMatrix: Identifiable, Codable {
        let id: String
        let department: String
        let item: String
        let businessImpact: Double
        let urgency: Double
        let effort: Double
        let priorityScore: Double
    }

    // MARK: - Published State

    @Published private(set) var departmentHealth: [DepartmentHealth] = []
    @Published private(set) var dependencies: [DependencyMap] = []
    @Published private(set) var bottlenecks: [Bottleneck] = []
    @Published private(set) var priorityMatrix: [PriorityMatrix] = []
    @Published private(set) var sharedAlerts: [String] = []
    @Published private(set) var overallPlatformHealth: Double = 100

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cross-dept-intel-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCrossDepartmentIntel else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCrossDepartmentIntel else { return }

        // Load department health from Firestore
        let deptSnap = try? await db.collection("departmentHealth").getDocuments()
        departmentHealth = deptSnap?.documents.compactMap { doc in
            let d = doc.data()
            return DepartmentHealth(
                id: doc.documentID,
                department: d["department"] as? String ?? "",
                healthScore: d["healthScore"] as? Double ?? 100,
                activeTasks: d["activeTasks"] as? Int ?? 0,
                completedTasks24h: d["completedTasks24h"] as? Int ?? 0,
                avgResponseTimeMinutes: d["avgResponseTimeMinutes"] as? Double ?? 0,
                slaCompliance: d["slaCompliance"] as? Double ?? 100,
                staffingLevel: d["staffingLevel"] as? String ?? "normal",
                topBlocker: d["topBlocker"] as? String
            )
        } ?? []

        overallPlatformHealth = departmentHealth.isEmpty ? 100 : departmentHealth.reduce(0.0) { $0 + $1.healthScore } / Double(departmentHealth.count)

        // Cloud Run for dependency map, bottlenecks, priority matrix
        if let result = await callCloudRun(endpoint: "analyze") {
            if let deps = result["dependencies"] as? [[String: Any]] {
                dependencies = deps.compactMap { d in
                    DependencyMap(
                        id: UUID().uuidString,
                        source: d["source"] as? String ?? "",
                        target: d["target"] as? String ?? "",
                        dependencyType: d["dependencyType"] as? String ?? "",
                        strength: d["strength"] as? Double ?? 0,
                        latencyMs: d["latencyMs"] as? Int ?? 0,
                        errorRate: d["errorRate"] as? Double ?? 0
                    )
                }
            }
            if let bn = result["bottlenecks"] as? [[String: Any]] {
                bottlenecks = bn.compactMap { d in
                    Bottleneck(
                        id: UUID().uuidString,
                        department: d["department"] as? String ?? "",
                        process: d["process"] as? String ?? "",
                        avgDelayMinutes: d["avgDelayMinutes"] as? Double ?? 0,
                        affectedWorkflows: d["affectedWorkflows"] as? Int ?? 0,
                        rootCause: d["rootCause"] as? String ?? "",
                        recommendation: d["recommendation"] as? String ?? "",
                        severity: d["severity"] as? String ?? "medium"
                    )
                }
            }
            if let pm = result["priorityMatrix"] as? [[String: Any]] {
                priorityMatrix = pm.compactMap { d in
                    PriorityMatrix(
                        id: UUID().uuidString,
                        department: d["department"] as? String ?? "",
                        item: d["item"] as? String ?? "",
                        businessImpact: d["businessImpact"] as? Double ?? 0,
                        urgency: d["urgency"] as? Double ?? 0,
                        effort: d["effort"] as? Double ?? 0,
                        priorityScore: d["priorityScore"] as? Double ?? 0
                    )
                }
            }
            sharedAlerts = result["sharedAlerts"] as? [String] ?? []
        }
    }
}
