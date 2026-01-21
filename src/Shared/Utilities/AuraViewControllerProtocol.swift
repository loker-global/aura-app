// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AuraViewControllerProtocol.swift — Shared interface for platform views

import Foundation

// MARK: - AuraViewControllerProtocol

/// Defines the interface that both iOS and macOS view controllers must implement.
/// Allows shared coordinator logic to work with platform-specific views.
public protocol AuraViewControllerProtocol: AnyObject {
    
    // MARK: - State Display
    
    /// Updates the UI to reflect the current application state.
    func updateState(_ state: AppState)
    
    /// Updates the displayed recording duration.
    func updateRecordingDuration(_ duration: TimeInterval)
    
    /// Updates the displayed playback position.
    func updatePlaybackPosition(_ position: TimeInterval, duration: TimeInterval)
    
    /// Updates the displayed export progress.
    func updateExportProgress(_ progress: Float)
    
    /// Shows an error message to the user.
    func showError(_ error: AuraError)
    
    /// Updates the device list in the UI.
    func updateDeviceList(_ devices: [AudioDevice], selected: AudioDevice?)
    
    // MARK: - User Actions
    
    /// Called when the user wants to start recording.
    func handleStartRecording()
    
    /// Called when the user wants to stop recording.
    func handleStopRecording()
    
    /// Called when the user wants to cancel recording.
    func handleCancelRecording()
    
    /// Called when the user wants to start playback.
    func handleStartPlayback(fileURL: URL)
    
    /// Called when the user wants to toggle playback.
    func handleTogglePlayback()
    
    /// Called when the user wants to stop playback.
    func handleStopPlayback()
    
    /// Called when the user wants to export.
    func handleExport()
    
    /// Called when the user wants to cancel export.
    func handleCancelExport()
    
    /// Called when the user selects a device.
    func handleSelectDevice(_ device: AudioDevice)
    
    /// Called when the user wants to open a file.
    func handleOpenFile()
}

// MARK: - KeyboardShortcut

/// Keyboard shortcuts per KEYBOARD-SHORTCUTS.md.
public enum KeyboardShortcut {
    // Primary actions
    case startRecording        // Space or R (idle)
    case stopRecording         // Space or R (recording)
    case cancelRecording       // Esc (recording)
    case togglePlayback        // Space (playback)
    case stopPlayback          // Esc or S (playback)
    case cancelExport          // Esc (exporting)
    
    // Secondary actions
    case openFile              // Cmd+O
    case exportVideo           // Cmd+E
    case exportAudio           // Cmd+Shift+E
    case deviceSettings        // Cmd+D
    case showHelp              // Cmd+? or F1
    
    // macOS specific
    case toggleFullscreen      // Cmd+Ctrl+F
    case quit                  // Cmd+Q
    
    /// Returns the shortcut that should be active for a given state.
    public static func shortcuts(for state: AppState) -> [KeyboardShortcut] {
        switch state {
        case .idle:
            return [.startRecording, .openFile, .deviceSettings, .showHelp]
        case .recording:
            return [.stopRecording, .cancelRecording]
        case .playback(_, _, _, let isPaused):
            var shortcuts: [KeyboardShortcut] = [.togglePlayback, .stopPlayback, .showHelp]
            if isPaused {
                shortcuts.append(contentsOf: [.exportVideo, .exportAudio])
            }
            return shortcuts
        case .exporting:
            return [.cancelExport]
        case .error:
            return [.showHelp]
        }
    }
}

// MARK: - Formatting Utilities

/// Utility functions for formatting time and values for display.
public enum AuraFormatter {
    
    /// Formats a time interval as MM:SS or HH:MM:SS
    public static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Formats a progress value as percentage
    public static func formatProgress(_ progress: Float) -> String {
        return "\(Int(progress * 100))%"
    }
    
    /// Formats file size in human-readable format
    public static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
