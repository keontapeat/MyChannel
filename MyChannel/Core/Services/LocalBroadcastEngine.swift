import Foundation
import CoreBluetooth

/// Phase 99: CoreBluetooth Local Broadcast
/// Broadcasts the currently playing video ID over BLE so nearby strangers can see what you're watching.
@MainActor
final class LocalBroadcastEngine: NSObject, ObservableObject {
    static let shared = LocalBroadcastEngine()
    
    private var peripheralManager: CBPeripheralManager!
    private var centralManager: CBCentralManager!
    
    // Custom UUID for MyChannel Watch Party Service
    private let watchPartyServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6C")
    
    @Published var currentlyWatchingVideoId: String?
    @Published var nearbyStrangersWatching: [String: String] = [:] // Peripheral ID -> Video ID
    
    private override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Starts broadcasting the given video ID
    func startBroadcasting(videoId: String) {
        self.currentlyWatchingVideoId = videoId
        
        guard peripheralManager.state == .poweredOn else { return }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [watchPartyServiceUUID],
            CBAdvertisementDataLocalNameKey: "MyChannel:\(videoId)"
        ]
        
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising(advertisementData)
        print("📡 [CoreBluetooth] Started broadcasting video: \(videoId)")
    }
    
    func stopBroadcasting() {
        self.currentlyWatchingVideoId = nil
        peripheralManager.stopAdvertising()
        print("📡 [CoreBluetooth] Stopped broadcasting.")
    }
    
    /// Scans for other nearby users watching MyChannel
    func startScanningForNearbyUsers() {
        guard centralManager.state == .poweredOn else { return }
        
        centralManager.scanForPeripherals(withServices: [watchPartyServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        print("📡 [CoreBluetooth] Scanning for nearby users...")
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
}

extension LocalBroadcastEngine: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            Task { @MainActor in
                if let videoId = self.currentlyWatchingVideoId {
                    self.startBroadcasting(videoId: videoId)
                }
            }
        }
    }
}

extension LocalBroadcastEngine: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            Task { @MainActor in
                self.startScanningForNearbyUsers()
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            if localName.hasPrefix("MyChannel:") {
                let videoId = localName.replacingOccurrences(of: "MyChannel:", with: "")
                Task { @MainActor in
                    self.nearbyStrangersWatching[peripheral.identifier.uuidString] = videoId
                    print("👀 [CoreBluetooth] Found stranger watching: \(videoId)")
                }
            }
        }
    }
}
