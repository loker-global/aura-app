// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AppState.swift — Application state definitions

import Foundation

// MARK: - AppState

/// AURA application state machine.
/// Per ARCHITECTURE.md: Single source of truth for application state.
///
/// States:
/// - idle: Live orb, not recording
/// - recording: WAV writer active
/// - playback: Orb driven by file
/// - exporting: Offline render
/// - error: Safe failure state
public enum AppState: Equatable {
    
    // MARK: - Cases
    
    /// Live orb mode - microphone active, not recording.
    /// User can start recording or load a file for playback.
    case idle(selectedDevice: AudioDevice?)
    
    /// Recording in progress.
    /// Audio is being written to WAV file.
    case recording(
        device: AudioDevice,
        startTime: Date,
        fileURL: URL
    )
    
    /// Playing back a recorded file.
    /// Orb is driven by audio analysis of the file.
    case playback(
        fileURL: URL,
        position: TimeInterval,
        duration: TimeInterval,
        isPaused: Bool
    )
    
    /// Exporting video.
    /// Offline rendering in progress.
    case exporting(
        sourceURL: URL,
        outputURL: URL,
        progress: Float
    )
    
    /// Error state.
    /// Safe failure with user-friendly message.
    case error(AuraError)
    
    // MARK: - Convenience Properties
    
    /// Whether the app is in idle state
    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    /// Whether recording is in progress
    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    /// Whether playback is active (playing or paused)
    public var isPlayback: Bool {
        if case .playback = self { return true }
        return false
    }
    
    /// Whether playback is paused
    public var isPlaybackPaused: Bool {
        if case .playback(_, _, _, let isPaused) = self {
            return isPaused
        }
        return false
    }
    
    /// Whether export is in progress
    public var isExporting: Bool {
        if case .exporting = self { return true }
        return false
    }
    
    /// Whether the state is an error
    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    /// Selected audio device (if in idle or recording)
    public var selectedDevice: AudioDevice? {
        switch self {
        case .idle(let device):
            return device
        case .recording(let device, _, _):
            return device
        default:
            return nil
        }
    }
    
    /// Current file URL (if in playback or exporting)
    public var currentFileURL: URL? {
        switch self {
        case .recording(_, _, let url):
            return url
        case .playback(let url, _, _, _):
            return url
        case .exporting(let source, _, _):
            return source
        default:
            return nil
        }
    }
    
    // MARK: - State Validation
    
    /// Whether device switching is allowed in current state
    public var canSwitchDevice: Bool {
        return isIdle
    }
    
    /// Whether recording can start in current state
    public var canStartRecording: Bool {
        return isIdle && selectedDevice != nil
    }
    
    /// Whether playback can start in current state
    public var canStartPlayback: Bool {
        return isIdle || isPlayback
    }
    
    /// Whether export can start in current state
    public var canStartExport: Bool {
        return isPlayback
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle(let d1), .idle(let d2)):
            return d1?.id == d2?.id
        case (.recording(let d1, let t1, let u1), .recording(let d2, let t2, let u2)):
            return d1.id == d2.id && t1 == t2 && u1 == u2
        case (.playback(let u1, let p1, let d1, let ip1), .playback(let u2, let p2, let d2, let ip2)):
            return u1 == u2 && p1 == p2 && d1 == d2 && ip1 == ip2
        case (.exporting(let s1, let o1, let p1), .exporting(let s2, let o2, let p2)):
            return s1 == s2 && o1 == o2 && p1 == p2
        case (.error(let e1), .error(let e2)):
            return e1.code == e2.code
        default:
            return false
        }
    }
}

// MARK: - AuraError

/// Application error type with user-friendly messages.
/// Per ERROR-MESSAGES.md: Calm, non-alarming communication.
public struct AuraError: Error, Equatable {
    
    /// Error code for identification
    public let code: String
    
    /// User-facing message (calm, clear, no jargon)
    public let message: String
    
    /// Optional detail (for partial file saves, etc.)
    public let detail: String?
    
    /// Recovery action, if available
    public let recovery: RecoveryAction?
    
    /// Error category
    public let category: Category
    
    // MARK: - Categories
    
    public enum Category {
        /// User can fix immediately
        case recoverable
        /// May resolve on retry
        case transient
        /// Cannot proceed, must return to safe state
        case blocking
    }
    
    // MARK: - Recovery Actions
    
    public enum RecoveryAction {
        case openSettings
        case tryAgain
        case chooseFile
        case chooseLocation
        case useBuiltInMic
        case none
    }
    
    // MARK: - Predefined Errors
    
    /// Microphone permission denied
    public static let microphonePermissionDenied = AuraError(
        code: "mic_permission_denied",
        message: "Microphone access is required to record.",
        detail: nil,
        recovery: .openSettings,
        category: .recoverable
    )
    
    /// Disk space low warning
    public static let diskSpaceLow = AuraError(
        code: "disk_space_low",
        message: "Low disk space. Recording may stop if space runs out.",
        detail: nil,
        recovery: .none,
        category: .recoverable
    )
    
    /// Disk full during recording
    public static func diskFull(partialFile: URL?) -> AuraError {
        AuraError(
            code: "disk_full",
            message: "Recording stopped. Disk is full.",
            detail: partialFile.map { "Partial recording saved: \($0.lastPathComponent)" },
            recovery: .none,
            category: .blocking
        )
    }
    
    /// Audio device disconnected
    public static func deviceDisconnected(name: String, partialFile: URL?) -> AuraError {
        AuraError(
            code: "device_disconnected",
            message: "\(name) disconnected. Recording stopped.",
            detail: partialFile.map { "Partial recording saved: \($0.lastPathComponent)" },
            recovery: .useBuiltInMic,
            category: .blocking
        )
    }
    
    /// Device unavailable
    public static func deviceUnavailable(name: String) -> AuraError {
        AuraError(
            code: "device_unavailable",
            message: "Could not access \(name). It may be unavailable.",
            detail: nil,
            recovery: .useBuiltInMic,
            category: .transient
        )
    }
    
    /// Device in use by another app
    public static func deviceInUse(name: String) -> AuraError {
        AuraError(
            code: "device_in_use",
            message: "Could not access \(name). It may be in use by another app.",
            detail: nil,
            recovery: .tryAgain,
            category: .transient
        )
    }
    
    /// File not found
    public static func fileNotFound(url: URL) -> AuraError {
        AuraError(
            code: "file_not_found",
            message: "Could not open file. It may have been moved or deleted.",
            detail: nil,
            recovery: .chooseFile,
            category: .recoverable
        )
    }
    
    /// Unsupported file format
    public static func unsupportedFormat(format: String) -> AuraError {
        AuraError(
            code: "unsupported_format",
            message: "This file format is not supported. Use WAV or MP3.",
            detail: nil,
            recovery: .chooseFile,
            category: .recoverable
        )
    }
    
    /// Export failed (generic)
    public static let exportFailed = AuraError(
        code: "export_failed",
        message: "Export could not complete. Try again or choose a different location.",
        detail: nil,
        recovery: .tryAgain,
        category: .transient
    )
    
    /// Export canceled
    public static let exportCanceled = AuraError(
        code: "export_canceled",
        message: "Export canceled.",
        detail: nil,
        recovery: .none,
        category: .recoverable
    )
    
    /// No input devices found
    public static let noInputDevices = AuraError(
        code: "no_input_devices",
        message: "No microphone found. Connect a microphone to record.",
        detail: nil,
        recovery: .none,
        category: .blocking
    )
    
    /// Audio engine crashed
    public static let audioEngineCrashed = AuraError(
        code: "audio_engine_crashed",
        message: "Audio stopped unexpectedly. Restart the app to continue.",
        detail: nil,
        recovery: .none,
        category: .blocking
    )
    
    /// Permission denied for file system
    public static let filePermissionDenied = AuraError(
        code: "file_permission_denied",
        message: "Cannot save to this location. Choose a different folder.",
        detail: nil,
        recovery: .chooseLocation,
        category: .recoverable
    )
    
    // MARK: - Initialization
    
    public init(
        code: String,
        message: String,
        detail: String? = nil,
        recovery: RecoveryAction? = nil,
        category: Category = .transient
    ) {
        self.code = code
        self.message = message
        self.detail = detail
        self.recovery = recovery
        self.category = category
    }
}

// MARK: - State Transitions

/// Defines valid state transitions for the AURA state machine.
public enum StateTransition {
    case startRecording(device: AudioDevice, fileURL: URL)
    case stopRecording
    case cancelRecording
    case startPlayback(fileURL: URL, duration: TimeInterval)
    case pausePlayback
    case resumePlayback
    case stopPlayback
    case seekPlayback(position: TimeInterval)
    case updatePlaybackPosition(position: TimeInterval)
    case startExport(sourceURL: URL, outputURL: URL)
    case updateExportProgress(progress: Float)
    case completeExport
    case cancelExport
    case selectDevice(device: AudioDevice?)
    case reportError(error: AuraError)
    case dismissError
    
    /// Validates whether this transition is allowed from the given state.
    /// - Parameter currentState: The current application state
    /// - Returns: True if the transition is valid
    public func isValid(from currentState: AppState) -> Bool {
        switch (self, currentState) {
        // Recording transitions
        case (.startRecording, .idle):
            return currentState.selectedDevice != nil
        case (.stopRecording, .recording), (.cancelRecording, .recording):
            return true
            
        // Playback transitions
        case (.startPlayback, .idle), (.startPlayback, .playback):
            return true
        case (.pausePlayback, .playback(_, _, _, false)):
            return true
        case (.resumePlayback, .playback(_, _, _, true)):
            return true
        case (.stopPlayback, .playback), (.seekPlayback, .playback), (.updatePlaybackPosition, .playback):
            return true
            
        // Export transitions
        case (.startExport, .playback):
            return true
        case (.updateExportProgress, .exporting), (.completeExport, .exporting), (.cancelExport, .exporting):
            return true
            
        // Device selection
        case (.selectDevice, .idle):
            return true
            
        // Error handling
        case (.reportError, _):
            return true
        case (.dismissError, .error):
            return true
            
        default:
            return false
        }
    }
}
