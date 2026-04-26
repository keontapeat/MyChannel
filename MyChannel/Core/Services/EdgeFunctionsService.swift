//
//  EdgeFunctionsService.swift
//  MyChannel
//
//  Edge function execution: serverless compute at the edge,
//  A/B testing, personalization, geo-routing. Uses `cdn-optimizer-v2` Cloud Run.
//

import Foundation

struct EdgeFunction: Codable, Identifiable {
    let id: String
    let name: String
    let region: String
    let runtime: String
    let memoryMB: Int
    let timeoutSec: Int
    let invokeCount: Int
    let avgLatencyMs: Double
}

struct EdgeFunctionResult: Codable {
    let functionId: String
    let status: Int
    let body: String
    let latencyMs: Double
    let region: String
}

@MainActor
final class EdgeFunctionsService: ObservableObject {
    static let shared = EdgeFunctionsService()
    private init() {}
    @Published private(set) var functions: [EdgeFunction] = []

    func listFunctions() async throws {
        struct Req: Encodable { let task: String }
        struct RawF: Decodable { let id: String; let name: String; let region: String; let runtime: String; let memory: Int?; let timeout: Int?; let invocations: Int?; let latency: Double? }
        struct Raw: Decodable { let functions: [RawF]? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict", body: Req(task: "list_edge_functions"))
        functions = (r.functions ?? []).map {
            EdgeFunction(id: $0.id, name: $0.name, region: $0.region, runtime: $0.runtime,
                memoryMB: $0.memory ?? 128, timeoutSec: $0.timeout ?? 30, invokeCount: $0.invocations ?? 0, avgLatencyMs: $0.latency ?? 0)
        }
    }

    func invoke(functionId: String, payload: [String: String] = [:]) async throws -> EdgeFunctionResult {
        struct Req: Encodable { let task: String; let functionId: String; let payload: [String: String] }
        struct Raw: Decodable { let status: Int?; let body: String?; let latency: Double?; let region: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict",
            body: Req(task: "invoke_edge_function", functionId: functionId, payload: payload), timeout: 30)
        return EdgeFunctionResult(functionId: functionId, status: r.status ?? 200, body: r.body ?? "",
            latencyMs: r.latency ?? 0, region: r.region ?? "")
    }

    func deploy(name: String, code: String, region: String = "us-central1") async throws -> EdgeFunction {
        struct Req: Encodable { let task: String; let name: String; let code: String; let region: String }
        struct Raw: Decodable { let id: String; let runtime: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict",
            body: Req(task: "deploy_edge_function", name: name, code: code, region: region), timeout: 45)
        let fn = EdgeFunction(id: r.id, name: name, region: region, runtime: r.runtime ?? "swift",
            memoryMB: 128, timeoutSec: 30, invokeCount: 0, avgLatencyMs: 0)
        functions.append(fn); return fn
    }
}
