import SwiftUI
import Combine

// MARK: - Player Controls Coordinator
/// Centralizes player control visibility, auto-hide timing, and transient overlay lifecycle.
/// This reduces @State sprawl in VideoDetailView and makes player interaction coordination safer.
@MainActor
final class PlayerControlsCoordinator: ObservableObject {
    
    // MARK: - Control Visibility
    @Published var showControls: Bool = true
    @Published var isPlaying: Bool = false
    
    // MARK: - Transient Overlays
    @Published var showSeekOverlay: Bool = false
    @Published var showBrightnessOverlay: Bool = false
    @Published var showVolumeOverlay: Bool = false
    @Published var hoveredChapter: Video.Chapter? = nil
    
    // MARK: - Internal State
    private var hideTimer: Timer?
    private var chapterTooltipWorkItem: DispatchWorkItem?
    private var chapterTooltipX: CGFloat = 0
    
    /// Time before controls auto-hide when playing (seconds)
    var autoHideDelay: TimeInterval = 5.0
    
    /// Whether any transient overlay is currently visible
    var hasTransientOverlay: Bool {
        showSeekOverlay || showBrightnessOverlay || showVolumeOverlay || hoveredChapter != nil
    }
    
    // MARK: - Control Visibility Management
    
    /// Show controls and reset the auto-hide timer if playing
    func showControlsAndResetTimer() {
        showControls = true
        resetHideTimer()
    }
    
    /// Toggle control visibility
    func toggleControls() {
        showControls.toggle()
        if showControls {
            resetHideTimer()
        } else {
            cancelHideTimer()
        }
    }
    
    /// Hide controls immediately
    func hideControls() {
        showControls = false
        cancelHideTimer()
    }
    
    // MARK: - Auto-Hide Timer
    
    func resetHideTimer() {
        cancelHideTimer()
        
        // Only auto-hide if playing and no transient overlays
        guard isPlaying && !hasTransientOverlay else { return }
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isPlaying && !self.hasTransientOverlay else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showControls = false
                }
            }
        }
    }
    
    func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    func pauseAutoHideForTransientOverlay() {
        cancelHideTimer()
        if !showControls {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = true
            }
        }
    }
    
    func resumeAutoHideIfNeeded() {
        guard !hasTransientOverlay else { return }
        resetHideTimer()
    }
    
    // MARK: - Transient Overlay Management
    
    func beginSeekOverlay() {
        withAnimation(.easeOut(duration: 0.1)) {
            showSeekOverlay = true
        }
        pauseAutoHideForTransientOverlay()
    }
    
    func endSeekOverlay() {
        withAnimation { showSeekOverlay = false }
        resumeAutoHideIfNeeded()
    }
    
    func beginBrightnessOverlay() {
        showBrightnessOverlay = true
        pauseAutoHideForTransientOverlay()
    }
    
    func endBrightnessOverlay() {
        showBrightnessOverlay = false
        resumeAutoHideIfNeeded()
    }
    
    func beginVolumeOverlay() {
        showVolumeOverlay = true
        pauseAutoHideForTransientOverlay()
    }
    
    func endVolumeOverlay() {
        showVolumeOverlay = false
        resumeAutoHideIfNeeded()
    }
    
    // MARK: - Chapter Tooltip
    
    func updateHoveredChapter(at locationX: CGFloat, 
                            trackWidth: CGFloat, 
                            chapters: [Video.Chapter],
                            duration: TimeInterval) -> Video.Chapter? {
        guard duration > 0, !chapters.isEmpty else {
            hoveredChapter = nil
            return nil
        }
        
        let clampedX = max(0, min(trackWidth, locationX))
        let threshold: CGFloat = 18
        
        let chapterWithDistance = chapters
            .map { chapter -> (Video.Chapter, CGFloat) in
                let progress = max(0, min(1, chapter.start / duration))
                let chapterX = CGFloat(progress) * trackWidth
                return (chapter, abs(chapterX - clampedX))
            }
            .min(by: { $0.1 < $1.1 })
        
        guard let (chapter, distance) = chapterWithDistance, distance <= threshold else {
            hoveredChapter = nil
            return nil
        }
        
        chapterTooltipWorkItem?.cancel()
        chapterTooltipX = clampedX
        
        if hoveredChapter?.id != chapter.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredChapter = chapter
            }
        }
        
        pauseAutoHideForTransientOverlay()
        return chapter
    }
    
    func clearHoveredChapter() {
        chapterTooltipWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.15)) {
                self?.hoveredChapter = nil
            }
            self?.resumeAutoHideIfNeeded()
        }
        chapterTooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }
    
    func immediateClearHoveredChapter() {
        chapterTooltipWorkItem?.cancel()
        hoveredChapter = nil
    }
    
    // MARK: - Playback State
    
    func updatePlayingState(_ playing: Bool) {
        isPlaying = playing
        if playing {
            resetHideTimer()
        } else {
            cancelHideTimer()
            // Keep controls visible when paused
            if !showControls {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = true
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        cancelHideTimer()
        chapterTooltipWorkItem?.cancel()
        chapterTooltipWorkItem = nil
    }
}
