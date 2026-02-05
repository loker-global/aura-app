// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// StateManager.swift — Application state management

import Foundation
import Combine

// MARK: - StateManagerDelegate

/// Delegate for receiving state change notifications.
public protocol StateManagerDelegate: AnyObject {
    /// Called when the application state changes.
    func stateManager(_ manager: StateManager, didTransitionTo state: AppState, from previousState: AppState)
    
    /// Called when an invalid transition is attempted.
    func stateManager(_ manager: StateManager, rejectedTransition transition: StateTransition, from state: AppState)
}

// MARK: - StateManager

/// Single source of truth for AURA application state.
/// Per ARCHITECTURE.md: Thread-safe, validates transitions, publishes state changes.
///
/// Thread Safety: All state changes are dispatched to the main thread.
@MainActor
public final class StateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current application state
    @Published public private(set) var currentState: AppState
    
    /// State history for debugging
    public private(set) var stateHistory: [AppState] = []
    
    // MARK: - Properties
    
    /// Delegate for state change notifications
    public weak var delegate: StateManagerDelegate?
    
    /// Maximum history entries to keep
    private let maxHistorySize = 100
    
    // MARK: - Initialization
    
    public init(initialDevice: AudioDevice? = nil) {
        self.currentState = .idle(selectedDevice: initialDevice)
        self.stateHistory = [currentState]
    }
    
    // MARK: - Public Methods
    
    /// Applies a state transition.
    /// - Parameter transition: The transition to apply
    /// - Returns: True if the transition was applied successfully
    @discardableResult
    public func apply(_ transition: StateTransition) -> Bool {
        // Validate transition
        guard transition.isValid(from: currentState) else {
            delegate?.stateManager(self, rejectedTransition: transition, from: currentState)
            return false
        }
        
        let previousState = currentState
        
        // Apply transition
        switch transition {
        case .startRecording(let device, let fileURL):
            currentState = .recording(
                device: device,
                startTime: Date(),
                fileURL: fileURL
            )
            
        case .stopRecording:
            if case .recording = currentState {
                // Return to idle with same device
                currentState = .idle(selectedDevice: currentState.selectedDevice)
            }
            
        case .cancelRecording:
            if case .recording = currentState {
                currentState = .idle(selectedDevice: currentState.selectedDevice)
            }
            
        case .startPlayback(let fileURL, let duration):
            currentState = .playback(
                fileURL: fileURL,
                position: 0,
                duration: duration,
                isPaused: false
            )
            
        case .pausePlayback:
            if case .playback(let url, let pos, let dur, _) = currentState {
                currentState = .playback(
                    fileURL: url,
                    position: pos,
                    duration: dur,
                    isPaused: true
                )
            }
            
        case .resumePlayback:
            if case .playback(let url, let pos, let dur, _) = currentState {
                currentState = .playback(
                    fileURL: url,
                    position: pos,
                    duration: dur,
                    isPaused: false
                )
            }
            
        case .stopPlayback:
            currentState = .idle(selectedDevice: nil)
            
        case .seekPlayback(let position):
            if case .playback(let url, _, let dur, let paused) = currentState {
                currentState = .playback(
                    fileURL: url,
                    position: max(0, min(position, dur)),
                    duration: dur,
                    isPaused: paused
                )
            }
            
        case .updatePlaybackPosition(let position):
            if case .playback(let url, _, let dur, let paused) = currentState {
                currentState = .playback(
                    fileURL: url,
                    position: position,
                    duration: dur,
                    isPaused: paused
                )
            }
            
        case .startExport(let sourceURL, let outputURL):
            currentState = .exporting(
                sourceURL: sourceURL,
                outputURL: outputURL,
                progress: 0
            )
            
        case .updateExportProgress(let progress):
            if case .exporting(let source, let output, _) = currentState {
                currentState = .exporting(
                    sourceURL: source,
                    outputURL: output,
                    progress: progress
                )
            }
            
        case .completeExport:
            // Return to playback state with same file
            if case .exporting(let source, _, _) = currentState {
                currentState = .playback(
                    fileURL: source,
                    position: 0,
                    duration: 0, // Will be updated when playback starts
                    isPaused: true
                )
            }
            
        case .cancelExport:
            // Return to playback state
            if case .exporting(let source, _, _) = currentState {
                currentState = .playback(
                    fileURL: source,
                    position: 0,
                    duration: 0,
                    isPaused: true
                )
            }
            
        case .selectDevice(let device):
            if case .idle = currentState {
                currentState = .idle(selectedDevice: device)
            }
            
        case .reportError(let error):
            currentState = .error(error)
            
        case .dismissError:
            if case .error = currentState {
                currentState = .idle(selectedDevice: nil)
            }
        }
        
        // Record in history
        addToHistory(currentState)
        
        // Notify delegate
        if currentState != previousState {
            delegate?.stateManager(self, didTransitionTo: currentState, from: previousState)
        }
        
        return true
    }
    
    /// Resets to idle state.
    /// - Parameter device: Optional device to select
    public func reset(device: AudioDevice? = nil) {
        let previousState = currentState
        currentState = .idle(selectedDevice: device)
        addToHistory(currentState)
        
        if currentState != previousState {
            delegate?.stateManager(self, didTransitionTo: currentState, from: previousState)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Whether recording can start now
    public var canStartRecording: Bool {
        currentState.canStartRecording
    }
    
    /// Whether device switching is allowed
    public var canSwitchDevice: Bool {
        currentState.canSwitchDevice
    }
    
    /// Whether export can start
    public var canStartExport: Bool {
        currentState.canStartExport
    }
    
    /// Selected device (if any)
    public var selectedDevice: AudioDevice? {
        currentState.selectedDevice
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ state: AppState) {
        stateHistory.append(state)
        
        // Trim history if too large
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst(stateHistory.count - maxHistorySize)
        }
    }
}

// MARK: - StateManager+Convenience

extension StateManager {
    
    /// Starts recording with the selected device.
    /// - Parameter fileURL: The URL to save the recording
    /// - Returns: True if recording started
    @discardableResult
    public func startRecording(to fileURL: URL) -> Bool {
        guard let device = selectedDevice else { return false }
        return apply(.startRecording(device: device, fileURL: fileURL))
    }
    
    /// Stops the current recording.
    @discardableResult
    public func stopRecording() -> Bool {
        apply(.stopRecording)
    }
    
    /// Cancels the current recording (deletes file).
    @discardableResult
    public func cancelRecording() -> Bool {
        apply(.cancelRecording)
    }
    
    /// Starts playback of a file.
    /// - Parameters:
    ///   - fileURL: The audio file URL
    ///   - duration: The file duration in seconds
    @discardableResult
    public func startPlayback(of fileURL: URL, duration: TimeInterval) -> Bool {
        apply(.startPlayback(fileURL: fileURL, duration: duration))
    }
    
    /// Toggles playback between play and pause.
    public func togglePlayback() {
        if case .playback(_, _, _, let isPaused) = currentState {
            if isPaused {
                apply(.resumePlayback)
            } else {
                apply(.pausePlayback)
            }
        }
    }
    
    /// Stops playback and returns to idle.
    @discardableResult
    public func stopPlayback() -> Bool {
        apply(.stopPlayback)
    }
    
    /// Seeks to a position in the current playback.
    /// - Parameter position: Target position in seconds
    @discardableResult
    public func seekTo(_ position: TimeInterval) -> Bool {
        apply(.seekPlayback(position: position))
    }
    
    /// Starts exporting the current file.
    /// - Parameter outputURL: The output file URL
    @discardableResult
    public func startExport(to outputURL: URL) -> Bool {
        guard case .playback(let fileURL, _, _, _) = currentState else {
            return false
        }
        return apply(.startExport(sourceURL: fileURL, outputURL: outputURL))
    }
    
    /// Cancels the current export.
    @discardableResult
    public func cancelExport() -> Bool {
        apply(.cancelExport)
    }
    
    /// Reports an error.
    /// - Parameter error: The error to report
    public func reportError(_ error: AuraError) {
        apply(.reportError(error: error))
    }
    
    /// Dismisses the current error.
    public func dismissError() {
        apply(.dismissError)
    }
}

// MARK: - StateManager+Debug

extension StateManager {
    
    /// Returns a debug description of the current state.
    public var debugDescription: String {
        switch currentState {
        case .idle(let device):
            return "Idle (device: \(device?.name ?? "none"))"
        case .recording(let device, let start, let url):
            let duration = Date().timeIntervalSince(start)
            return "Recording (\(device.name), \(String(format: "%.1f", duration))s, \(url.lastPathComponent))"
        case .playback(let url, let pos, let dur, let paused):
            return "Playback (\(url.lastPathComponent), \(String(format: "%.1f", pos))/\(String(format: "%.1f", dur))s, \(paused ? "paused" : "playing"))"
        case .exporting(_, let output, let progress):
            return "Exporting (\(output.lastPathComponent), \(Int(progress * 100))%)"
        case .error(let error):
            return "Error (\(error.code): \(error.message))"
        }
    }
    
    /// Prints state history for debugging.
    public func printHistory() {
        print("=== State History ===")
        for (index, state) in stateHistory.enumerated() {
            let stateManager = StateManager(initialDevice: nil)
            // Temporarily set state for description
            print("[\(index)] \(state)")
        }
        print("=====================")
    }
}
