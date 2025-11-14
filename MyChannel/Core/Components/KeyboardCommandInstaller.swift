//
//  KeyboardCommandInstaller.swift
//  MyChannel
//
//  Installs common YouTube-style keyboard shortcuts for iPad/hardware keyboards.
//

import SwiftUI
import UIKit

struct KeyboardCommandInstaller: UIViewControllerRepresentable {
    let onPlayPause: () -> Void
    let onBack10: () -> Void
    let onForward10: () -> Void
    let onMuteToggle: () -> Void
    let onFullscreenToggle: () -> Void
    let onFrameStepForward: () -> Void
    let onFrameStepBack: () -> Void
    let onVolumeUp: () -> Void
    let onVolumeDown: () -> Void
    
    func makeUIViewController(context: Context) -> InstallerHostController {
        InstallerHostController(self)
    }
    
    func updateUIViewController(_ uiViewController: InstallerHostController, context: Context) {}
    
    final class InstallerHostController: UIViewController {
        let installer: KeyboardCommandInstaller
        init(_ installer: KeyboardCommandInstaller) {
            self.installer = installer
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        override var keyCommands: [UIKeyCommand]? {
            return [
                UIKeyCommand(input: "k", modifierFlags: [], action: #selector(togglePlayPause)),
                UIKeyCommand(input: " ", modifierFlags: [], action: #selector(togglePlayPause)),
                UIKeyCommand(input: "j", modifierFlags: [], action: #selector(back10)),
                UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(back10)),
                UIKeyCommand(input: "l", modifierFlags: [], action: #selector(forward10)),
                UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(forward10)),
                UIKeyCommand(input: "m", modifierFlags: [], action: #selector(muteToggle)),
                UIKeyCommand(input: "f", modifierFlags: [], action: #selector(fullscreenToggle)),
                UIKeyCommand(input: ",", modifierFlags: [], action: #selector(frameBack)),
                UIKeyCommand(input: ".", modifierFlags: [], action: #selector(frameForward)),
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(volumeUp)),
                UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(volumeDown))
            ]
        }
        
        @objc private func togglePlayPause() { installer.onPlayPause() }
        @objc private func back10() { installer.onBack10() }
        @objc private func forward10() { installer.onForward10() }
        @objc private func muteToggle() { installer.onMuteToggle() }
        @objc private func fullscreenToggle() { installer.onFullscreenToggle() }
        @objc private func frameForward() { installer.onFrameStepForward() }
        @objc private func frameBack() { installer.onFrameStepBack() }
        @objc private func volumeUp() { installer.onVolumeUp() }
        @objc private func volumeDown() { installer.onVolumeDown() }
    }
}


