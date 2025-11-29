//
//  DownloadScheduler.swift
//  MyChannel
//
//  ⏰🔥 INTELLIGENT DOWNLOAD SCHEDULER 🔥⏰
//  YouTube Premium-level scheduling with device awareness
//
//  Features:
//  - Battery-aware scheduling
//  - Charging detection
//  - WiFi-only enforcement
//  - Time-of-day preferences
//  - Low data mode awareness
//  - Background task integration
//

import Foundation
import Combine
import UIKit
import BackgroundTasks

// MARK: - Download Scheduler
@MainActor
final class DownloadScheduler: ObservableObject {
    static let shared = DownloadScheduler()
    
    // MARK: - Published State
    @Published private(set) var scheduledDownloads: [ScheduledDownload] = []
    @Published private(set) var isSchedulingEnabled: Bool = true
    @Published private(set) var nextScheduledTime: Date?
    @Published private(set) var deviceConditions: DeviceConditions = .init()
    
    // MARK: - Settings
    @Published var requireWiFi: Bool = true
    @Published var requireCharging: Bool = false
    @Published var minimumBatteryLevel: Int = 20
    @Published var preferredTimeWindows: [TimeWindow] = [
        TimeWindow(start: 2, end: 6, isEnabled: true),   // Overnight
        TimeWindow(start: 22, end: 24, isEnabled: true)  // Late evening
    ]
    @Published var maxDailyDownloads: Int = 50
    @Published var respectLowDataMode: Bool = true
    
    // MARK: - Private Properties
    private let downloadManager = NuclearDownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var batteryMonitor: Timer?
    private var conditionCheckTimer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Tracking
    private var dailyDownloadCount: Int = 0
    private var lastResetDate: Date = Date()
    
    // MARK: - Initialization
    private init() {
        setupBatteryMonitoring()
        setupConditionChecking()
        loadSettings()
        registerBackgroundTasks()
        
        // Monitor network changes
        downloadManager.$networkStatus
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.evaluateConditions()
                }
            }
            .store(in: &cancellables)
        
        print("⏰ [Scheduler] Initialized")
    }
    
    deinit {
        batteryMonitor?.invalidate()
        conditionCheckTimer?.invalidate()
    }
    
    // MARK: - Public API
    
    /// Schedule a video for download at optimal time
    func scheduleDownload(
        _ video: Video,
        quality: NuclearDownloadQuality = .medium,
        priority: SchedulePriority = .normal,
        deadline: Date? = nil
    ) -> ScheduledDownload {
        
        let scheduled = ScheduledDownload(
            id: UUID().uuidString,
            video: video,
            quality: quality,
            priority: priority,
            scheduledAt: Date(),
            deadline: deadline,
            status: .pending,
            estimatedStartTime: calculateOptimalStartTime(for: video, deadline: deadline)
        )
        
        scheduledDownloads.append(scheduled)
        sortScheduledDownloads()
        updateNextScheduledTime()
        saveSettings()
        
        // Check if we can start immediately
        Task {
            await evaluateConditions()
        }
        
        print("⏰ [Scheduler] Scheduled: \(video.title) for \(scheduled.estimatedStartTime?.formatted() ?? "optimal time")")
        
        return scheduled
    }
    
    /// Schedule multiple videos
    func scheduleDownloads(_ videos: [Video], quality: NuclearDownloadQuality = .medium) -> [ScheduledDownload] {
        return videos.map { scheduleDownload($0, quality: quality) }
    }
    
    /// Cancel a scheduled download
    func cancelScheduled(_ id: String) {
        scheduledDownloads.removeAll { $0.id == id }
        updateNextScheduledTime()
        saveSettings()
    }
    
    /// Cancel all scheduled downloads
    func cancelAllScheduled() {
        scheduledDownloads.removeAll()
        nextScheduledTime = nil
        saveSettings()
    }
    
    /// Force start downloads now (ignore conditions)
    func startDownloadsNow() async {
        print("⏰ [Scheduler] Force starting downloads...")
        
        for scheduled in scheduledDownloads.filter({ $0.status == .pending }) {
            await startScheduledDownload(scheduled)
        }
    }
    
    /// Check if conditions are optimal for downloading
    func areConditionsOptimal() -> Bool {
        // WiFi check
        if requireWiFi && downloadManager.networkStatus != .wifi {
            return false
        }
        
        // Battery check
        if deviceConditions.batteryLevel < minimumBatteryLevel && !deviceConditions.isCharging {
            return false
        }
        
        // Charging check
        if requireCharging && !deviceConditions.isCharging {
            return false
        }
        
        // Low data mode check
        if respectLowDataMode && deviceConditions.isLowDataMode {
            return false
        }
        
        // Time window check
        if !isInPreferredTimeWindow() && !preferredTimeWindows.isEmpty {
            return false
        }
        
        // Daily limit check
        if dailyDownloadCount >= maxDailyDownloads {
            return false
        }
        
        return true
    }
    
    /// Get reason why conditions aren't optimal
    func getConditionBlockers() -> [ConditionBlocker] {
        var blockers: [ConditionBlocker] = []
        
        if requireWiFi && downloadManager.networkStatus != .wifi {
            blockers.append(.noWiFi)
        }
        
        if deviceConditions.batteryLevel < minimumBatteryLevel && !deviceConditions.isCharging {
            blockers.append(.lowBattery(level: deviceConditions.batteryLevel))
        }
        
        if requireCharging && !deviceConditions.isCharging {
            blockers.append(.notCharging)
        }
        
        if respectLowDataMode && deviceConditions.isLowDataMode {
            blockers.append(.lowDataMode)
        }
        
        if !isInPreferredTimeWindow() && !preferredTimeWindows.isEmpty {
            blockers.append(.outsideTimeWindow)
        }
        
        if dailyDownloadCount >= maxDailyDownloads {
            blockers.append(.dailyLimitReached)
        }
        
        return blockers
    }
    
    // MARK: - Condition Evaluation
    
    private func evaluateConditions() async {
        updateDeviceConditions()
        
        // Reset daily count if new day
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyDownloadCount = 0
            lastResetDate = Date()
        }
        
        // Check if conditions are good
        guard areConditionsOptimal() else {
            print("⏰ [Scheduler] Conditions not optimal: \(getConditionBlockers())")
            return
        }
        
        // Start pending downloads
        let pendingDownloads = scheduledDownloads.filter { $0.status == .pending }
        
        for scheduled in pendingDownloads {
            // Check deadline
            if let deadline = scheduled.deadline, Date() > deadline {
                await handleMissedDeadline(scheduled)
                continue
            }
            
            // Check if it's time
            if let estimatedStart = scheduled.estimatedStartTime, Date() >= estimatedStart {
                await startScheduledDownload(scheduled)
            } else if scheduled.estimatedStartTime == nil {
                // No specific time, start now if conditions good
                await startScheduledDownload(scheduled)
            }
        }
    }
    
    private func startScheduledDownload(_ scheduled: ScheduledDownload) async {
        guard dailyDownloadCount < maxDailyDownloads else { return }
        
        // Update status
        if let index = scheduledDownloads.firstIndex(where: { $0.id == scheduled.id }) {
            scheduledDownloads[index].status = .downloading
        }
        
        do {
            _ = try await downloadManager.downloadVideo(
                scheduled.video,
                quality: scheduled.quality,
                priority: scheduled.priority == .high ? .high : .normal
            )
            
            // Mark as completed
            if let index = scheduledDownloads.firstIndex(where: { $0.id == scheduled.id }) {
                scheduledDownloads[index].status = .completed
                scheduledDownloads[index].completedAt = Date()
            }
            
            dailyDownloadCount += 1
            
            print("⏰ [Scheduler] Started download: \(scheduled.video.title)")
            
        } catch {
            // Mark as failed
            if let index = scheduledDownloads.firstIndex(where: { $0.id == scheduled.id }) {
                scheduledDownloads[index].status = .failed
                scheduledDownloads[index].errorMessage = error.localizedDescription
            }
            
            print("⏰ [Scheduler] Failed to start: \(error)")
        }
        
        updateNextScheduledTime()
        saveSettings()
    }
    
    private func handleMissedDeadline(_ scheduled: ScheduledDownload) async {
        if let index = scheduledDownloads.firstIndex(where: { $0.id == scheduled.id }) {
            scheduledDownloads[index].status = .missed
        }
        
        print("⏰ [Scheduler] Missed deadline for: \(scheduled.video.title)")
    }
    
    // MARK: - Time Calculation
    
    private func calculateOptimalStartTime(for video: Video, deadline: Date?) -> Date? {
        // If deadline is soon, return nil (start ASAP when conditions allow)
        if let deadline = deadline {
            let hoursUntilDeadline = deadline.timeIntervalSince(Date()) / 3600
            if hoursUntilDeadline < 4 {
                return nil // Start ASAP
            }
        }
        
        // Find next preferred time window
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        // Check each time window
        for window in preferredTimeWindows where window.isEnabled {
            if currentHour >= window.start && currentHour < window.end {
                // We're in a window now
                return nil // Start ASAP
            }
            
            // Calculate time until this window
            var nextWindowStart = calendar.date(bySettingHour: window.start, minute: 0, second: 0, of: now)!
            
            if nextWindowStart <= now {
                // Window already passed today, try tomorrow
                nextWindowStart = calendar.date(byAdding: .day, value: 1, to: nextWindowStart)!
            }
            
            // Check against deadline
            if let deadline = deadline, nextWindowStart > deadline {
                continue // Skip this window
            }
            
            return nextWindowStart
        }
        
        // No preferred windows or all passed deadline
        return nil
    }
    
    private func isInPreferredTimeWindow() -> Bool {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        for window in preferredTimeWindows where window.isEnabled {
            if currentHour >= window.start && currentHour < window.end {
                return true
            }
        }
        
        return preferredTimeWindows.isEmpty // If no windows set, always OK
    }
    
    // MARK: - Device Monitoring
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateDeviceConditions()
                await self?.evaluateConditions()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateDeviceConditions()
                await self?.evaluateConditions()
            }
        }
    }
    
    private func setupConditionChecking() {
        // Check conditions every 5 minutes
        conditionCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.evaluateConditions()
            }
        }
    }
    
    private func updateDeviceConditions() {
        let device = UIDevice.current
        
        deviceConditions = DeviceConditions(
            batteryLevel: Int(device.batteryLevel * 100),
            isCharging: device.batteryState == .charging || device.batteryState == .full,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isLowDataMode: false, // Would need Network framework to check
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.mychannel.download.scheduler",
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleBackgroundTask(task as! BGProcessingTask)
            }
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) async {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        await evaluateConditions()
        
        task.setTaskCompleted(success: true)
        scheduleBackgroundTask()
    }
    
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.mychannel.download.scheduler")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = requireCharging
        
        // Schedule for next preferred time window
        if let nextTime = calculateNextTimeWindowStart() {
            request.earliestBeginDate = nextTime
        }
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func calculateNextTimeWindowStart() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        for window in preferredTimeWindows.sorted(by: { $0.start < $1.start }) where window.isEnabled {
            var nextStart = calendar.date(bySettingHour: window.start, minute: 0, second: 0, of: now)!
            
            if nextStart <= now {
                nextStart = calendar.date(byAdding: .day, value: 1, to: nextStart)!
            }
            
            return nextStart
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    private func sortScheduledDownloads() {
        scheduledDownloads.sort { a, b in
            // Priority first
            if a.priority != b.priority {
                return a.priority.rawValue > b.priority.rawValue
            }
            
            // Then deadline
            if let deadlineA = a.deadline, let deadlineB = b.deadline {
                return deadlineA < deadlineB
            } else if a.deadline != nil {
                return true
            } else if b.deadline != nil {
                return false
            }
            
            // Then scheduled time
            return a.scheduledAt < b.scheduledAt
        }
    }
    
    private func updateNextScheduledTime() {
        let pending = scheduledDownloads.filter { $0.status == .pending }
        nextScheduledTime = pending.compactMap { $0.estimatedStartTime }.min()
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        let settings = SchedulerSettings(
            requireWiFi: requireWiFi,
            requireCharging: requireCharging,
            minimumBatteryLevel: minimumBatteryLevel,
            preferredTimeWindows: preferredTimeWindows,
            maxDailyDownloads: maxDailyDownloads,
            respectLowDataMode: respectLowDataMode,
            scheduledDownloads: scheduledDownloads,
            dailyDownloadCount: dailyDownloadCount,
            lastResetDate: lastResetDate
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: "download_scheduler_settings")
        }
    }
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: "download_scheduler_settings"),
              let settings = try? JSONDecoder().decode(SchedulerSettings.self, from: data) else {
            return
        }
        
        requireWiFi = settings.requireWiFi
        requireCharging = settings.requireCharging
        minimumBatteryLevel = settings.minimumBatteryLevel
        preferredTimeWindows = settings.preferredTimeWindows
        maxDailyDownloads = settings.maxDailyDownloads
        respectLowDataMode = settings.respectLowDataMode
        scheduledDownloads = settings.scheduledDownloads
        dailyDownloadCount = settings.dailyDownloadCount
        lastResetDate = settings.lastResetDate
        
        updateNextScheduledTime()
    }
}

// MARK: - Models

struct ScheduledDownload: Identifiable, Codable {
    let id: String
    let video: Video
    let quality: NuclearDownloadQuality
    let priority: SchedulePriority
    let scheduledAt: Date
    let deadline: Date?
    var status: ScheduleStatus
    var estimatedStartTime: Date?
    var completedAt: Date?
    var errorMessage: String?
}

enum SchedulePriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    
    static func < (lhs: SchedulePriority, rhs: SchedulePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

enum ScheduleStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
    case missed
}

struct TimeWindow: Codable, Identifiable {
    var id: String { "\(start)-\(end)" }
    let start: Int // Hour (0-23)
    let end: Int   // Hour (0-23)
    var isEnabled: Bool
    
    var displayName: String {
        let startFormatted = formatHour(start)
        let endFormatted = formatHour(end)
        return "\(startFormatted) - \(endFormatted)"
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 24 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour) AM" }
        return "\(hour - 12) PM"
    }
}

struct DeviceConditions {
    var batteryLevel: Int = 100
    var isCharging: Bool = false
    var isLowPowerMode: Bool = false
    var isLowDataMode: Bool = false
    var thermalState: ProcessInfo.ThermalState = .nominal
    
    var isOptimal: Bool {
        return batteryLevel > 20 && !isLowPowerMode && thermalState != .critical
    }
}

enum ConditionBlocker: CustomStringConvertible {
    case noWiFi
    case lowBattery(level: Int)
    case notCharging
    case lowDataMode
    case outsideTimeWindow
    case dailyLimitReached
    case thermalThrottling
    
    var description: String {
        switch self {
        case .noWiFi:
            return "Waiting for WiFi connection"
        case .lowBattery(let level):
            return "Battery too low (\(level)%)"
        case .notCharging:
            return "Waiting for device to charge"
        case .lowDataMode:
            return "Low Data Mode is enabled"
        case .outsideTimeWindow:
            return "Outside preferred download time"
        case .dailyLimitReached:
            return "Daily download limit reached"
        case .thermalThrottling:
            return "Device is too warm"
        }
    }
    
    var icon: String {
        switch self {
        case .noWiFi: return "wifi.slash"
        case .lowBattery: return "battery.25"
        case .notCharging: return "bolt.slash"
        case .lowDataMode: return "arrow.down.circle"
        case .outsideTimeWindow: return "clock"
        case .dailyLimitReached: return "number.circle"
        case .thermalThrottling: return "thermometer.sun"
        }
    }
}

struct SchedulerSettings: Codable {
    let requireWiFi: Bool
    let requireCharging: Bool
    let minimumBatteryLevel: Int
    let preferredTimeWindows: [TimeWindow]
    let maxDailyDownloads: Int
    let respectLowDataMode: Bool
    let scheduledDownloads: [ScheduledDownload]
    let dailyDownloadCount: Int
    let lastResetDate: Date
}
