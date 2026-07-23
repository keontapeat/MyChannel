import SwiftUI
import AVKit

// MARK: - Casting Hub
// AirPlay: uses native AVRoutePickerView (no entitlement needed — works out of the box).
// Chromecast: requires GoogleCast SDK. We wrap it behind a protocol so the
// feature compiles cleanly whether or not the SDK is linked yet.

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

    func startScan() {
        isScanning = true
        // AirPlay devices surface through the system AVRoutePickerView — no manual scan needed.
        // Chromecast: call GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
        // when the SDK is linked. For now we surface a placeholder so the UI is fully built.
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            // In production: populate from GCKCastContext / AVRouteDetector callbacks.
            // Placeholder keeps the empty-state logic honest.
            isScanning = false
        }
    }

    func connect(to device: CastDevice) {
        HapticManager.shared.impact(style: .medium)
        connectedDeviceId = device.id
        // Chromecast: GCKCastContext.sharedInstance().sessionManager.startSession(with: …)
        // AirPlay: handled automatically by AVRoutePickerView; no manual connect needed.
    }

    func disconnect() {
        HapticManager.shared.impact(style: .rigid)
        connectedDeviceId = nil
        // Chromecast: GCKCastContext.sharedInstance().sessionManager.endSession()
    }
}

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
