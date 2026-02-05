// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AuraCoordinator.swift — Module coordination and integration

import Foundation
import AVFoundation
import Combine

// MARK: - AuraCoordinatorDelegate

/// Delegate for receiving coordinator events.
public protocol AuraCoordinatorDelegate: AnyObject {
    /// Called when audio features are updated (for UI metering).
    func auraCoordinator(_ coordinator: AuraCoordinator, didUpdateFeatures features: AudioFeatures)
    
    /// Called when playback position updates.
    func auraCoordinator(_ coordinator: AuraCoordinator, didUpdatePlaybackPosition position: TimeInterval, duration: TimeInterval)
    
    /// Called when export progress updates.
    func auraCoordinator(_ coordinator: AuraCoordinator, didUpdateExportProgress progress: Float)
    
    /// Called when an error occurs.
    func auraCoordinator(_ coordinator: AuraCoordinator, didEncounterError error: AuraError)
    
    /// Called when recording completes.
    func auraCoordinator(_ coordinator: AuraCoordinator, didCompleteRecordingTo fileURL: URL)
    
    /// Called when export completes.
    func auraCoordinator(_ coordinator: AuraCoordinator, didCompleteExportTo fileURL: URL)
}

// MARK: - AuraCoordinator

/// Connects audio engine → physics → renderer.
/// Per ARCHITECTURE.md: Platform-independent business logic.
///
/// Responsibilities:
/// - Routes audio buffers to recorder + orb physics
/// - Handles export workflow
/// - Listens to StateManager changes
/// - Coordinates all module interactions
@MainActor
public final class AuraCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    /// Current application state (mirrors StateManager)
    @Published public private(set) var state: AppState
    
    /// Current audio features (for UI display)
    @Published public private(set) var currentFeatures: AudioFeatures = .silent
    
    /// Recording duration (seconds)
    @Published public private(set) var recordingDuration: TimeInterval = 0
    
    /// Playback position (seconds)
    @Published public private(set) var playbackPosition: TimeInterval = 0
    
    /// Playback duration (seconds)
    @Published public private(set) var playbackDuration: TimeInterval = 0
    
    /// Export progress (0.0 - 1.0)
    @Published public private(set) var exportProgress: Float = 0
    
    // MARK: - Components
    
    /// State manager (single source of truth)
    public let stateManager: StateManager
    
    /// Audio device registry
    public let deviceRegistry: AudioDeviceRegistry
    
    /// Audio capture engine
    public let captureEngine: AudioCaptureEngine
    
    /// WAV file recorder
    public let wavRecorder: WavRecorder
    
    /// Audio file player
    public let audioPlayer: AudioPlayer
    
    /// Orb physics simulation
    public let orbPhysics: OrbPhysics
    
    /// Orb renderer
    public let orbRenderer: OrbRenderer
    
    /// Video exporter
    public private(set) var orbExporter: OrbExporter?
    
    // MARK: - Properties
    
    /// Delegate for coordinator events
    public weak var delegate: AuraCoordinatorDelegate?
    
    /// Available audio input devices
    public private(set) var availableDevices: [AudioDevice] = []
    
    // MARK: - Private Properties
    
    private var recordingTimer: Timer?
    private var physicsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        // Initialize components
        self.stateManager = StateManager()
        self.deviceRegistry = AudioDeviceRegistry()
        self.captureEngine = AudioCaptureEngine()
        self.wavRecorder = WavRecorder()
        self.audioPlayer = AudioPlayer()
        self.orbPhysics = OrbPhysics()
        self.orbRenderer = OrbRenderer()
        
        // Set initial state
        self.state = stateManager.currentState
        
        // Setup delegates
        captureEngine.delegate = self
        wavRecorder.delegate = self
        audioPlayer.delegate = self
        orbRenderer.delegate = self
        stateManager.delegate = self
        
        // Observe state changes
        stateManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
        
        // Load available devices
        refreshDevices()
        deviceRegistry.startObservingDeviceChanges { [weak self] devices in
            self?.handleDeviceListChanged(devices)
        }
        
        // Start physics update timer
        startPhysicsTimer()
    }
    
    deinit {
        stopPhysicsTimer()
        deviceRegistry.stopObservingDeviceChanges()
    }
    
    // MARK: - Device Management
    
    /// Refreshes the list of available audio devices.
    public func refreshDevices() {
        availableDevices = deviceRegistry.enumerateInputDevices()
        
        // Auto-select default device if none selected
        if stateManager.selectedDevice == nil {
            if let defaultDevice = deviceRegistry.defaultInputDevice() {
                stateManager.apply(.selectDevice(device: defaultDevice))
            } else if let firstDevice = availableDevices.first {
                stateManager.apply(.selectDevice(device: firstDevice))
            }
        }
    }
    
    /// Selects an audio input device.
    /// - Parameter device: The device to select
    public func selectDevice(_ device: AudioDevice) {
        guard stateManager.canSwitchDevice else { return }
        
        do {
            try captureEngine.selectDevice(device)
            stateManager.apply(.selectDevice(device: device))
        } catch {
            delegate?.auraCoordinator(self, didEncounterError: .deviceUnavailable(name: device.name))
        }
    }
    
    // MARK: - Recording
    
    /// Requests microphone permission.
    /// - Parameter completion: Called with result
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        captureEngine.requestPermission(completion: completion)
    }
    
    /// Starts recording.
    public func startRecording() {
        guard stateManager.canStartRecording else { return }
        guard let device = stateManager.selectedDevice else { return }
        
        // Check disk space
        let (canRecord, isLowSpace) = WavRecorder.checkDiskSpace()
        
        if !canRecord {
            stateManager.reportError(.diskFull(partialFile: nil))
            return
        }
        
        if isLowSpace {
            // Show warning but continue
            // Could notify delegate here if needed
        }
        
        do {
            // Start capture engine
            try captureEngine.start()
            
            // Get audio format from capture engine
            guard let format = captureEngine.audioFormat else {
                throw AudioCaptureError.unexpectedFormat
            }
            
            // Start WAV recorder
            let recordingsDir = try WavRecorder.recordingsDirectory()
            let fileURL = WavRecorder.generateFilename(in: recordingsDir)
            
            try wavRecorder.startRecording(format: format)
            
            // Update state
            if let actualURL = wavRecorder.currentFileURL {
                stateManager.apply(.startRecording(device: device, fileURL: actualURL))
                startRecordingTimer()
            }
            
            // Reset physics for new recording
            orbPhysics.reset()
            
        } catch {
            captureEngine.stop()
            delegate?.auraCoordinator(self, didEncounterError: .audioEngineCrashed)
        }
    }
    
    /// Stops recording.
    public func stopRecording() {
        guard stateManager.currentState.isRecording else { return }
        
        stopRecordingTimer()
        captureEngine.stop()
        wavRecorder.stopRecording()
        
        if let fileURL = wavRecorder.currentFileURL {
            stateManager.apply(.stopRecording)
            delegate?.auraCoordinator(self, didCompleteRecordingTo: fileURL)
        } else {
            stateManager.apply(.stopRecording)
        }
    }
    
    /// Cancels recording (deletes file).
    public func cancelRecording() {
        guard stateManager.currentState.isRecording else { return }
        
        stopRecordingTimer()
        captureEngine.stop()
        wavRecorder.cancelRecording()
        stateManager.apply(.cancelRecording)
    }
    
    // MARK: - Playback
    
    /// Starts playback of an audio file.
    /// - Parameter fileURL: The audio file URL
    public func startPlayback(of fileURL: URL) {
        do {
            try audioPlayer.loadFile(at: fileURL)
            
            stateManager.apply(.startPlayback(fileURL: fileURL, duration: audioPlayer.duration))
            playbackDuration = audioPlayer.duration
            
            audioPlayer.play()
            orbPhysics.reset()
            
        } catch {
            delegate?.auraCoordinator(self, didEncounterError: .fileNotFound(url: fileURL))
        }
    }
    
    /// Toggles playback between play and pause.
    public func togglePlayback() {
        audioPlayer.togglePlayPause()
        stateManager.togglePlayback()
    }
    
    /// Pauses playback.
    public func pausePlayback() {
        audioPlayer.pause()
        stateManager.apply(.pausePlayback)
    }
    
    /// Resumes playback.
    public func resumePlayback() {
        audioPlayer.play()
        stateManager.apply(.resumePlayback)
    }
    
    /// Stops playback and returns to idle.
    public func stopPlayback() {
        audioPlayer.stop()
        stateManager.apply(.stopPlayback)
        playbackPosition = 0
        playbackDuration = 0
    }
    
    /// Seeks to a position in playback.
    /// - Parameter position: Target position in seconds
    public func seekTo(_ position: TimeInterval) {
        audioPlayer.seek(to: position)
        stateManager.apply(.seekPlayback(position: position))
    }
    
    // MARK: - Export
    
    /// Starts video export.
    /// - Parameter outputURL: The output file URL
    public func startExport(to outputURL: URL) {
        guard case .playback(let sourceURL, _, _, _) = stateManager.currentState else {
            return
        }
        
        orbExporter = OrbExporter(configuration: .standard)
        orbExporter?.delegate = self
        
        stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        orbExporter?.startExport(audioURL: sourceURL, outputURL: outputURL)
    }
    
    /// Cancels the current export.
    public func cancelExport() {
        orbExporter?.cancelExport()
        stateManager.apply(.cancelExport)
        orbExporter = nil
    }
    
    // MARK: - Physics & Rendering
    
    /// Starts the physics update timer.
    private func startPhysicsTimer() {
        physicsTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0, // 60 Hz
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePhysics()
            }
        }
        
        if let timer = physicsTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stops the physics update timer.
    private func stopPhysicsTimer() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }
    
    /// Updates physics based on current audio features.
    private func updatePhysics() {
        orbPhysics.applyForces(
            radialForce: currentFeatures.rms,
            tension: currentFeatures.surfaceTension(),
            rippleAmplitude: currentFeatures.zeroCrossingRate,
            impulse: currentFeatures.impulseForce(),
            isSilent: currentFeatures.isSilent
        )
        
        orbPhysics.update()
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration = self?.wavRecorder.recordingDuration ?? 0
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    // MARK: - Device Changes
    
    private func handleDeviceListChanged(_ devices: [AudioDevice]) {
        availableDevices = devices
        
        // Check if current device was disconnected
        if let selected = stateManager.selectedDevice,
           !devices.contains(where: { $0.id == selected.id }) {
            
            // Device disconnected
            if stateManager.currentState.isRecording {
                // Stop recording if in progress
                stopRecording()
                delegate?.auraCoordinator(self, didEncounterError: .deviceDisconnected(
                    name: selected.name,
                    partialFile: wavRecorder.currentFileURL
                ))
            }
            
            // Fall back to default device
            if let defaultDevice = devices.first(where: { $0.isDefault }) ?? devices.first {
                selectDevice(defaultDevice)
            } else {
                stateManager.apply(.selectDevice(device: nil))
            }
        }
    }
}

// MARK: - AudioCaptureDelegate

extension AuraCoordinator: AudioCaptureDelegate {
    
    nonisolated public func audioCaptureEngine(
        _ engine: AudioCaptureEngine,
        didCaptureBuffer buffer: AVAudioPCMBuffer,
        features: AudioFeatures
    ) {
        // Update features (on main thread)
        Task { @MainActor in
            self.currentFeatures = features
            self.delegate?.auraCoordinator(self, didUpdateFeatures: features)
        }
        
        // Write to recorder if recording
        if stateManager.currentState.isRecording {
            wavRecorder.writeBuffer(buffer)
        }
    }
    
    nonisolated public func audioCaptureEngine(
        _ engine: AudioCaptureEngine,
        didEncounterError error: AudioCaptureError
    ) {
        Task { @MainActor in
            // Convert to AuraError
            let auraError: AuraError
            switch error {
            case .permissionDenied:
                auraError = .microphonePermissionDenied
            case .deviceUnavailable(let name):
                auraError = .deviceUnavailable(name: name)
            case .deviceInUse(let name):
                auraError = .deviceInUse(name: name)
            default:
                auraError = .audioEngineCrashed
            }
            
            self.delegate?.auraCoordinator(self, didEncounterError: auraError)
        }
    }
    
    nonisolated public func audioCaptureEngine(
        _ engine: AudioCaptureEngine,
        didChangeState state: AudioCaptureEngine.State
    ) {
        // Handle state changes if needed
    }
}

// MARK: - WavRecorderDelegate

extension AuraCoordinator: WavRecorderDelegate {
    
    nonisolated public func wavRecorderDidStartRecording(_ recorder: WavRecorder, fileURL: URL) {
        // Recording started
    }
    
    nonisolated public func wavRecorderDidStopRecording(_ recorder: WavRecorder, fileURL: URL, duration: TimeInterval) {
        // Recording completed
    }
    
    nonisolated public func wavRecorder(_ recorder: WavRecorder, didEncounterError error: WavRecorderError) {
        Task { @MainActor in
            let auraError: AuraError
            switch error {
            case .diskFull:
                auraError = .diskFull(partialFile: recorder.currentFileURL)
            case .permissionDenied:
                auraError = .filePermissionDenied
            default:
                auraError = AuraError(
                    code: "recording_error",
                    message: error.localizedDescription ?? "Recording failed.",
                    recovery: .none,
                    category: .transient
                )
            }
            
            self.delegate?.auraCoordinator(self, didEncounterError: auraError)
        }
    }
}

// MARK: - AudioPlayerDelegate

extension AuraCoordinator: AudioPlayerDelegate {
    
    nonisolated public func audioPlayerDidStartPlaying(_ player: AudioPlayer) {
        // Playback started
    }
    
    nonisolated public func audioPlayerDidPause(_ player: AudioPlayer) {
        // Playback paused
    }
    
    nonisolated public func audioPlayerDidStop(_ player: AudioPlayer) {
        // Playback stopped
    }
    
    nonisolated public func audioPlayer(
        _ player: AudioPlayer,
        didAnalyzeFeatures features: AudioFeatures,
        atTime time: TimeInterval
    ) {
        Task { @MainActor in
            self.currentFeatures = features
            self.delegate?.auraCoordinator(self, didUpdateFeatures: features)
        }
    }
    
    nonisolated public func audioPlayer(
        _ player: AudioPlayer,
        didUpdatePosition position: TimeInterval,
        duration: TimeInterval
    ) {
        Task { @MainActor in
            self.playbackPosition = position
            self.stateManager.apply(.updatePlaybackPosition(position: position))
            self.delegate?.auraCoordinator(self, didUpdatePlaybackPosition: position, duration: duration)
        }
    }
    
    nonisolated public func audioPlayer(_ player: AudioPlayer, didEncounterError error: AudioPlayerError) {
        Task { @MainActor in
            let auraError: AuraError
            switch error {
            case .fileNotFound(let url):
                auraError = .fileNotFound(url: url)
            case .unsupportedFormat(let format):
                auraError = .unsupportedFormat(format: format)
            default:
                auraError = AuraError(
                    code: "playback_error",
                    message: error.localizedDescription ?? "Playback failed.",
                    recovery: .tryAgain,
                    category: .transient
                )
            }
            
            self.delegate?.auraCoordinator(self, didEncounterError: auraError)
        }
    }
}

// MARK: - OrbRendererDelegate

extension AuraCoordinator: OrbRendererDelegate {
    
    nonisolated public func orbRendererNeedsPhysicsUpdate(_ renderer: OrbRenderer) -> OrbShaderState? {
        // Return current physics state for rendering
        // This is called from render thread, so we access physics directly
        return orbPhysics.shaderState
    }
}

// MARK: - OrbExporterDelegate

extension AuraCoordinator: OrbExporterDelegate {
    
    nonisolated public func orbExporter(_ exporter: OrbExporter, didUpdateProgress progress: Float) {
        Task { @MainActor in
            self.exportProgress = progress
            self.stateManager.apply(.updateExportProgress(progress: progress))
            self.delegate?.auraCoordinator(self, didUpdateExportProgress: progress)
        }
    }
    
    nonisolated public func orbExporterDidComplete(_ exporter: OrbExporter, outputURL: URL) {
        Task { @MainActor in
            self.stateManager.apply(.completeExport)
            self.orbExporter = nil
            self.delegate?.auraCoordinator(self, didCompleteExportTo: outputURL)
        }
    }
    
    nonisolated public func orbExporter(_ exporter: OrbExporter, didFailWithError error: OrbExporterError) {
        Task { @MainActor in
            self.stateManager.apply(.cancelExport)
            self.orbExporter = nil
            self.delegate?.auraCoordinator(self, didEncounterError: .exportFailed)
        }
    }
    
    nonisolated public func orbExporterDidCancel(_ exporter: OrbExporter) {
        Task { @MainActor in
            self.stateManager.apply(.cancelExport)
            self.orbExporter = nil
        }
    }
}

// MARK: - StateManagerDelegate

extension AuraCoordinator: StateManagerDelegate {
    
    nonisolated public func stateManager(
        _ manager: StateManager,
        didTransitionTo state: AppState,
        from previousState: AppState
    ) {
        // State change handled via @Published property
    }
    
    nonisolated public func stateManager(
        _ manager: StateManager,
        rejectedTransition transition: StateTransition,
        from state: AppState
    ) {
        // Invalid transition - could log or handle
        print("[AuraCoordinator] Rejected transition: \(transition) from \(state)")
    }
}
