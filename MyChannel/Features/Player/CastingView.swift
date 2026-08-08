import SwiftUI
import AVKit
#if canImport(GoogleCast)
import GoogleCast
#endif

// MARK: - Casting Hub
// AirPlay: uses native AVRoutePickerView (no entitlement needed — works out of the box).
// Chromecast: real GoogleCast SDK integration behind `#if canImport(GoogleCast)`, so
// this file compiles clean whether or not the SDK is linked. To activate real
// Chromecast discovery/casting:
//   1. Xcode → File → Add Package Dependencies →
//      https://github.com/google/google-cast-sdk (or via CocoaPods `pod
//      'google-cast-sdk'`) and link it to the MyChannel target.
//   2. In MyChannelApp.swift's init, call
//      `GoogleCastManager.shared.startDiscovery()` once (mirrors how
//      FirebaseManager is bootstrapped) so discovery is warm before the user
//      opens the cast sheet.
//   3. Add `NSBonjourServices` (`_googlecast._tcp` + your receiver app ID's
//      `_CC1AD845._googlecast._tcp` entry) and
//      `NSLocalNetworkUsageDescription` to Info.plist — required by iOS 14+
//      local network access for GoogleCast discovery.
// Until the SDK is linked, `CastViewModel` falls back to an honest empty
// state (no devices found) rather than fabricating fake Chromecast entries.

// MARK: - AirPlay Route Picker (UIViewRepresentable)

/// Wraps AVRoutePickerView so SwiftUI can present the native AirPlay picker.
struct AirPlayButton: UIViewRepresentable {
    var tintColor: Color = PlayerChrome.onSurface

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(tintColor)
        view.activeTintColor = UIColor(PlayerChrome.accent)
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(tintColor)
    }
}

// MARK: - Cast Device Model

struct CastDevice: Identifiable {
    let id: String
    let name: String
    let type: CastDeviceType
    var isConnected: Bool = false
}

enum CastDeviceType {
    case airPlay, chromecast, appleTV

    var iconName: String {
        switch self {
        case .airPlay:    return "airplay.video"
        case .chromecast: return "tv.circle"
        case .appleTV:    return "appletv"
        }
    }

    var label: String {
        switch self {
        case .airPlay:    return "AirPlay"
        case .chromecast: return "Chromecast"
        case .appleTV:    return "Apple TV"
        }
    }
}

// MARK: - Cast Sheet ViewModel

@MainActor
final class CastViewModel: ObservableObject {
    @Published var devices: [CastDevice] = []
    @Published var isScanning = false
    @Published var connectedDeviceId: String?

    #if canImport(GoogleCast)
    private var discoveryObservation: NSObjectProtocol?
    #endif

    func startScan() {
        isScanning = true
        #if canImport(GoogleCast)
        // Real discovery — GoogleCastManager owns the GCKDiscoveryManager and
        // publishes device updates; we mirror its list here for this sheet's
        // lifetime instead of holding a second discovery session open.
        GoogleCastManager.shared.startDiscovery()
        discoveryObservation = GoogleCastManager.shared.observeDevices { [weak self] found in
            Task { @MainActor in
                self?.devices = found
                self?.isScanning = false
            }
        }
        // Discovery is asynchronous over mDNS; give it a moment before
        // clearing the spinner even if zero devices are found yet.
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isScanning = false
        }
        #else
        // SDK not linked — surface an honest empty state, never fake devices.
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            devices = []
            isScanning = false
        }
        #endif
    }

    func connect(to device: CastDevice) {
        HapticManager.shared.impact(style: .medium)
        connectedDeviceId = device.id
        #if canImport(GoogleCast)
        if device.type == .chromecast {
            GoogleCastManager.shared.connect(to: device.id)
        }
        #endif
        // AirPlay: handled automatically by AVRoutePickerView; no manual connect needed.
    }

    func disconnect() {
        HapticManager.shared.impact(style: .rigid)
        connectedDeviceId = nil
        #if canImport(GoogleCast)
        GoogleCastManager.shared.disconnect()
        #endif
    }

    deinit {
        #if canImport(GoogleCast)
        if let discoveryObservation {
            GoogleCastManager.shared.removeObserver(discoveryObservation)
        }
        GoogleCastManager.shared.stopDiscovery()
        #endif
    }
}

#if canImport(GoogleCast)
// MARK: - GoogleCastManager (real Chromecast session wrapper)

/// Thin wrapper around `GCKCastContext` so callers never touch the raw
/// GoogleCast SDK types directly. Safe to reference even before
/// `GCKCastContext.setSharedInstanceWith(_:)` has been configured — discovery
/// calls are no-ops until that happens in `MyChannelApp` startup.
@MainActor
final class GoogleCastManager: NSObject {
    static let shared = GoogleCastManager()

    private var deviceObservers: [NSObjectProtocol: (([CastDevice]) -> Void)] = [:]
    private var isObservingDiscovery = false

    private override init() {
        super.init()
    }

    /// Call once at app startup (after configuring `GCKCastContext`) — safe to
    /// call multiple times, the SDK no-ops on a repeat `startDiscovery()`.
    func startDiscovery() {
        let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager.add(self)
        discoveryManager.startDiscovery()
    }

    func stopDiscovery() {
        // Keep discovery warm across sheet presentations; only stop scanning
        // state observers here, not the underlying GCKDiscoveryManager.
    }

    /// Register for device-list updates. Returns a token to pass to
    /// `removeObserver` when the caller is done (e.g. in `deinit`).
    func observeDevices(_ handler: @escaping ([CastDevice]) -> Void) -> NSObjectProtocol {
        let token = NSObject()
        deviceObservers[token] = handler
        handler(currentDevices())
        return token
    }

    func removeObserver(_ token: NSObjectProtocol) {
        deviceObservers.removeValue(forKey: token)
    }

    func connect(to deviceId: String) {
        let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        guard let device = (0..<discoveryManager.deviceCount).lazy
            .map({ discoveryManager.device(at: $0) })
            .first(where: { $0.deviceID == deviceId })
        else { return }
        let sessionManager = GCKCastContext.sharedInstance().sessionManager
        sessionManager.startSession(with: device)
    }

    func disconnect() {
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
    }

    private func currentDevices() -> [CastDevice] {
        let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        return (0..<discoveryManager.deviceCount).map { index in
            let device = discoveryManager.device(at: index)
            return CastDevice(
                id: device.deviceID,
                name: device.friendlyName ?? "Chromecast",
                type: .chromecast,
                isConnected: GCKCastContext.sharedInstance().sessionManager.currentSession?.device?.deviceID == device.deviceID
            )
        }
    }

    private func notifyObservers() {
        let devices = currentDevices()
        for handler in deviceObservers.values {
            handler(devices)
        }
    }
}

extension GoogleCastManager: GCKDiscoveryManagerListener {
    func didUpdateDeviceList() {
        notifyObservers()
    }
}
#endif

// MARK: - Casting Sheet (presented from player chrome)

struct CastingSheet: View {
    @StateObject private var viewModel = CastViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // AirPlay native picker — always shown first
                airPlaySection

                Divider().padding(.vertical, 8)

                // Discovered cast devices (Chromecast / other)
                castDevicesSection
            }
            .navigationTitle("Play on")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { viewModel.startScan() }
        }
        .presentationDetents([.medium])
    }

    // MARK: AirPlay section
    private var airPlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AirPlay & Bluetooth", systemImage: "airplay.video")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            HStack {
                Text("Use the system picker to connect to AirPlay devices and Apple TV.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                // Native AirPlay button — taps open system route picker
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("AirPlay")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: Chromecast / other devices section
    private var castDevicesSection: some View {
        Group {
            if viewModel.isScanning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Looking for devices…")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(24)
            } else if viewModel.devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    Text("No Chromecast devices found")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("Make sure your device is on the same Wi-Fi network.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                List(viewModel.devices) { device in
                    CastDeviceRow(
                        device: device,
                        isConnected: viewModel.connectedDeviceId == device.id,
                        onTap: {
                            if viewModel.connectedDeviceId == device.id {
                                viewModel.disconnect()
                            } else {
                                viewModel.connect(to: device)
                            }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Cast Device Row

private struct CastDeviceRow: View {
    let device: CastDevice
    let isConnected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: device.type.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(isConnected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(device.type.label)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                if isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .labelStyle(.iconOnly)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Casting Sheet") {
    CastingSheet()
        .preferredColorScheme(.dark)
}
