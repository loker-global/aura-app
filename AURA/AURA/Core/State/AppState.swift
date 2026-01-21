import Foundation

/// Application state enum
/// Enforces state transitions
/// (from ARCHITECTURE.md)
enum AppState: Equatable {
    case idle(selectedDevice: AudioDevice?)
    case recording(device: AudioDevice, startTime: Date)
    case playback(file: URL, position: TimeInterval)
    case exporting(file: URL, progress: Float)
    case error(AuraError)
    
    // MARK: - Equatable
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle(let d1), .idle(let d2)):
            return d1 == d2
        case (.recording(let d1, _), .recording(let d2, _)):
            return d1 == d2
        case (.playback(let f1, _), .playback(let f2, _)):
            return f1 == f2
        case (.exporting(let f1, _), .exporting(let f2, _)):
            return f1 == f2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
    
    // MARK: - State Queries
    
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    var isPlayback: Bool {
        if case .playback = self { return true }
        return false
    }
    
    var isExporting: Bool {
        if case .exporting = self { return true }
        return false
    }
    
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    var canSwitchDevice: Bool {
        return isIdle
    }
    
    var canRecord: Bool {
        return isIdle
    }
    
    var canPlayback: Bool {
        return isIdle
    }
    
    var canExport: Bool {
        return isIdle
    }
}

// MARK: - Error Type

/// Application errors (from ERROR-MESSAGES.md)
enum AuraError: Error, Equatable {
    case microphonePermissionDenied
    case microphoneNotAvailable(String)
    case microphoneDisconnected
    case diskFull
    case fileWriteError(String)
    case fileReadError(String)
    case exportFailed(String)
    case unknownError(String)
    
    var title: String {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone Access Required"
        case .microphoneNotAvailable:
            return "Microphone Unavailable"
        case .microphoneDisconnected:
            return "Microphone Disconnected"
        case .diskFull:
            return "Storage Full"
        case .fileWriteError:
            return "Unable to Save"
        case .fileReadError:
            return "Unable to Open"
        case .exportFailed:
            return "Export Issue"
        case .unknownError:
            return "Something Went Wrong"
        }
    }
    
    var message: String {
        switch self {
        case .microphonePermissionDenied:
            return "AURA needs microphone access to capture your voice. Open System Preferences → Privacy → Microphone and enable access for AURA."
        case .microphoneNotAvailable(let name):
            return "\(name) isn't responding. Try unplugging and reconnecting, or select a different input."
        case .microphoneDisconnected:
            return "Your microphone was disconnected. Recording has stopped. Your file is safe."
        case .diskFull:
            return "There isn't enough space to continue. Free up some storage, and AURA will try again."
        case .fileWriteError(let path):
            return "AURA couldn't save to this location: \(path). Try a different folder."
        case .fileReadError(let path):
            return "This file couldn't be opened: \(path). It may be damaged or in an unsupported format."
        case .exportFailed(let reason):
            return "Export couldn't complete. \(reason)"
        case .unknownError(let details):
            return "Something unexpected happened. \(details)"
        }
    }
}
