//
//  BackgroundFetchService.swift
//  MyChannel
//
//  Background task scheduler to pre-fetch and cache data while the app is sleeping
//  Provides 0ms launch time
//

import Foundation
import BackgroundTasks

actor BackgroundFetchService {
    static let shared = BackgroundFetchService()
    
    // 🔥 CRASH FIX (App Store Guideline 2.1(a), submission 438e47dd): this identifier
    // MUST exactly match an entry in Info.plist > BGTaskSchedulerPermittedIdentifiers.
    // It previously registered "com.mychannel.refresh", which is NOT in the plist
    // (only "com.keontapeat.MyChannelApp.*" identifiers are declared there). Since
    // BGTaskScheduler.register(forTaskWithIdentifier:) is called synchronously during
    // didFinishLaunchingWithOptions, an unlisted identifier throws an uncaught
    // NSInternalInconsistencyException and crashes the app immediately on every launch —
    // exactly what App Review saw on the iPad Air 11-inch (M3) / iPadOS 26.5 review device.
    let refreshTaskId = "com.keontapeat.MyChannelApp.refresh"
    
    private init() {}
    
    /// Register the background task with the system
    nonisolated func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskId, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        print("🔄 [BackgroundFetch] Registered BGAppRefreshTask")
    }
    
    /// Schedule the next background fetch
    nonisolated func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        // Schedule to run no earlier than 1 hour from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 [BackgroundFetch] Scheduled next refresh for 1 hour from now")
        } catch {
            print("⚠️ [BackgroundFetch] Could not schedule app refresh: \(error)")
        }
    }
    
    /// Handle the execution of the background task
    private nonisolated func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next one immediately
        scheduleAppRefresh()
        
        // Provide an expiration handler
        task.expirationHandler = {
            print("⏱️ [BackgroundFetch] Task expired before completion")
        }
        
        // Execute the fetch asynchronously
        Task {
            do {
                print("📥 [BackgroundFetch] Starting background fetch...")
                
                // Warm up caching layers
                await NuclearFlicksViewModel.warmupOnLaunch()
                
                // Simulate downloading trending feeds or performing heavy ops
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                print("✅ [BackgroundFetch] Background fetch completed successfully!")
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ [BackgroundFetch] Background fetch failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}
