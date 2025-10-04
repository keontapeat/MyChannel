//
//  FlicksNetworkMonitor.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI
import Network
import Combine

// MARK: - 📡 Advanced Network Monitor for Flicks
@MainActor
class FlicksNetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType = .wifi
    @Published var connectionQuality: ConnectionQuality = .excellent
    @Published var downloadSpeed: Double = 0.0 // Mbps
    @Published var latency: TimeInterval = 0.0 // ms
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "FlicksNetworkMonitor")
    private var speedTestTimer: Timer?
    
    enum ConnectionQuality: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case offline = "Offline"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .offline: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.slash"
            case .poor: return "wifi.exclamationmark"
            case .offline: return "wifi.slash"
            }
        }
    }
    
    init() {
        startMonitoring()
        startSpeedTesting()
    }
    
    deinit {
        monitor.cancel()
        speedTestTimer?.invalidate()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isConnected = path.status == .satisfied
                self.connectionType = path.availableInterfaces.first?.type ?? .other
                
                if path.status == .satisfied {
                    self.assessConnectionQuality(path: path)
                } else {
                    self.connectionQuality = .offline
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func assessConnectionQuality(path: NWPath) {
        // Simulate connection quality assessment
        // In real implementation, you'd measure actual speed and latency
        
        if path.isExpensive {
            // Cellular connection
            connectionQuality = .fair
            downloadSpeed = Double.random(in: 5...25) // Typical cellular speeds
            latency = Double.random(in: 50...150)
        } else {
            // WiFi connection
            connectionQuality = .excellent
            downloadSpeed = Double.random(in: 25...100) // Typical WiFi speeds
            latency = Double.random(in: 10...50)
        }
    }
    
    private func startSpeedTesting() {
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSpeedTest()
            }
        }
    }
    
    private func performSpeedTest() async {
        guard isConnected else { return }
        
        // Simulate speed test
        // In real implementation, you'd perform actual network speed tests
        let testSpeed = Double.random(in: 10...100)
        let testLatency = Double.random(in: 20...200)
        
        downloadSpeed = testSpeed
        latency = testLatency
        
        // Update connection quality based on speed
        updateConnectionQuality(speed: testSpeed, latency: testLatency)
    }
    
    private func updateConnectionQuality(speed: Double, latency: TimeInterval) {
        if speed >= 50 && latency <= 50 {
            connectionQuality = .excellent
        } else if speed >= 25 && latency <= 100 {
            connectionQuality = .good
        } else if speed >= 10 && latency <= 150 {
            connectionQuality = .fair
        } else {
            connectionQuality = .poor
        }
    }
    
    func shouldPreloadHighQuality() -> Bool {
        return connectionQuality == .excellent && !monitor.currentPath.isExpensive
    }
    
    func shouldReduceQuality() -> Bool {
        return connectionQuality == .poor || monitor.currentPath.isExpensive
    }
    
    func getRecommendedVideoQuality() -> VideoQuality {
        switch connectionQuality {
        case .excellent:
            return .quality2160p // 4K
        case .good:
            return .quality1080p // Full HD
        case .fair:
            return .quality720p // HD
        case .poor:
            return .quality360p // SD
        case .offline:
            return .quality240p // Low quality
        }
    }
}

#Preview {
    @StateObject var networkMonitor = FlicksNetworkMonitor()
    
    return VStack(spacing: 20) {
        Text("Network Monitor")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(spacing: 16) {
            HStack {
                Image(systemName: networkMonitor.connectionQuality.icon)
                    .foregroundColor(networkMonitor.connectionQuality.color)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Connection: \(networkMonitor.connectionQuality.rawValue)")
                        .font(.headline)
                    Text(networkMonitor.isConnected ? "Connected" : "Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Download Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(networkMonitor.downloadSpeed, specifier: "%.1f") Mbps")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Latency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(networkMonitor.latency, specifier: "%.0f") ms")
                        .font(.headline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)
                
                Text("• Video Quality: \(networkMonitor.getRecommendedVideoQuality().displayName)")
                Text("• High Quality Preload: \(networkMonitor.shouldPreloadHighQuality() ? "Yes" : "No")")
                Text("• Reduce Quality: \(networkMonitor.shouldReduceQuality() ? "Yes" : "No")")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        
        Spacer()
    }
    .padding()
    .environmentObject(networkMonitor)
}