//
//  DistributedTracingService.swift
//  MyChannel
//
//  OpenTelemetry-style distributed tracing for request flows.
//  Span creation, context propagation, trace export.
//

import Foundation

struct TraceSpan: Codable, Identifiable {
    let id: String
    let traceId: String
    let parentSpanId: String?
    let operation: String
    let service: String
    let startAt: Date
    let endAt: Date?
    let status: SpanStatus
    let attributes: [String: String]
    enum SpanStatus: String, Codable { case ok, error, timeout }
}

struct Trace: Codable, Identifiable {
    let id: String
    let rootSpanId: String
    let spans: [TraceSpan]
    let durationMs: Double?
    let status: String
}

@MainActor
final class DistributedTracingService: ObservableObject {
    static let shared = DistributedTracingService()
    private init() {}
    @Published private(set) var activeSpans: [TraceSpan] = []
    @Published private(set) var recentTraces: [Trace] = []

    func startSpan(traceId: String, parentSpanId: String?, operation: String, service: String, attributes: [String: String] = [:]) -> TraceSpan {
        let span = TraceSpan(id: UUID().uuidString, traceId: traceId, parentSpanId: parentSpanId,
            operation: operation, service: service, startAt: Date(), endAt: nil, status: .ok, attributes: attributes)
        activeSpans.append(span)
        return span
    }

    func endSpan(spanId: String, status: TraceSpan.SpanStatus = .ok) {
        guard let idx = activeSpans.firstIndex(where: { $0.id == spanId }) else { return }
        let old = activeSpans[idx]
        let completed = TraceSpan(id: old.id, traceId: old.traceId, parentSpanId: old.parentSpanId,
            operation: old.operation, service: old.service, startAt: old.startAt, endAt: Date(), status: status, attributes: old.attributes)
        activeSpans.remove(at: idx)
        let duration = completed.endAt!.timeIntervalSince(completed.startAt) * 1000
        let trace = Trace(id: old.traceId, rootSpanId: old.id, spans: [completed], durationMs: duration, status: status.rawValue)
        recentTraces.insert(trace, at: 0)
        if recentTraces.count > 100 { recentTraces = Array(recentTraces.prefix(100)) }
    }

    func exportTraces() async throws -> [Trace] {
        struct Req: Encodable { let task: String }
        struct Raw: Decodable { let traces: [String]? }
        let _: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict", body: Req(task: "export_traces"))
        return recentTraces
    }

    func traceFor(traceId: String) -> Trace? { recentTraces.first { $0.id == traceId } }
}
