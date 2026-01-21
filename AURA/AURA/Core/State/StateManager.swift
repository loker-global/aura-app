import Foundation
import Combine

/// Single source of truth for application state
/// Enforces state transitions
/// Thread-safe
final class StateManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var currentState: AppState = .idle(selectedDevice: nil)
    @Published private(set) var virtualCameraActive = false
    
    // MARK: - Private
    
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    init() {
        // Load default device
        if let defaultDevice = AudioDeviceRegistry.shared.defaultInputDevice() {
            currentState = .idle(selectedDevice: defaultDevice)
        }
    }
    
    // MARK: - State Transitions
    
    /// Transition to idle state
    func setIdle(device: AudioDevice? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let selectedDevice = device ?? AudioDeviceRegistry.shared.defaultInputDevice()
        currentState = .idle(selectedDevice: selectedDevice)
    }
    
    /// Transition to recording state
    func setRecording(device: AudioDevice) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard currentState.canRecord else { return false }
        
        currentState = .recording(device: device, startTime: Date())
        return true
    }
    
    /// Transition to playback state
    func setPlayback(file: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard currentState.canPlayback else { return false }
        
        currentState = .playback(file: file, position: 0)
        return true
    }
    
    /// Update playback position
    func updatePlaybackPosition(_ position: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        
        if case .playback(let file, _) = currentState {
            currentState = .playback(file: file, position: position)
        }
    }
    
    /// Transition to exporting state
    func setExporting(file: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard currentState.canExport else { return false }
        
        currentState = .exporting(file: file, progress: 0)
        return true
    }
    
    /// Update export progress
    func updateExportProgress(_ progress: Float) {
        lock.lock()
        defer { lock.unlock() }
        
        if case .exporting(let file, _) = currentState {
            currentState = .exporting(file: file, progress: progress)
        }
    }
    
    /// Transition to error state
    func setError(_ error: AuraError) {
        lock.lock()
        defer { lock.unlock() }
        
        currentState = .error(error)
    }
    
    /// Select audio device (only in idle state)
    func selectDevice(_ device: AudioDevice) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard currentState.canSwitchDevice else { return false }
        
        currentState = .idle(selectedDevice: device)
        return true
    }
    
    // MARK: - Virtual Camera
    
    func setVirtualCameraActive(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        virtualCameraActive = active
    }
    
    // MARK: - Queries
    
    var selectedDevice: AudioDevice? {
        lock.lock()
        defer { lock.unlock() }
        
        if case .idle(let device) = currentState {
            return device
        }
        if case .recording(let device, _) = currentState {
            return device
        }
        return nil
    }
    
    var recordingDuration: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        
        if case .recording(_, let startTime) = currentState {
            return Date().timeIntervalSince(startTime)
        }
        return nil
    }
}
