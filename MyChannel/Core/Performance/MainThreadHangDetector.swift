//
//  MainThreadHangDetector.swift
//  MyChannel
//
//  Launch perf stub: logs when the main run loop stalls longer than threshold.
//  Wire into DEBUG builds only — production should use Instruments / MetricKit.
//

import Foundation

@MainActor
final class MainThreadHangDetector {
    static let shared = MainThreadHangDetector()

    private var watchdog: DispatchSourceTimer?
    private let thresholdMs: Int = 250
    private var lastPing = Date()

    private init() {}

    /// Starts a lightweight main-queue ping loop. No-op in Release.
    func startMonitoring() {
        #if DEBUG
        guard watchdog == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(thresholdMs), repeating: .milliseconds(thresholdMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let stallMs = Int(Date().timeIntervalSince(self.lastPing) * 1000)
            if stallMs > self.thresholdMs * 2 {
                print("⚠️ [MainThreadHangDetector] Main thread stall ~\(stallMs)ms")
            }
            self.lastPing = Date()
        }
        timer.resume()
        watchdog = timer
        print("⚡ [MainThreadHangDetector] Monitoring (threshold \(thresholdMs)ms)")
        #endif
    }

    func stopMonitoring() {
        watchdog?.cancel()
        watchdog = nil
    }
}
