import Foundation
import AVFoundation
import Metal
import Combine
import CoreVideo

/// Connects audio engine → physics → renderer
/// Handles state transitions
/// Platform-independent business logic
final class AuraCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    let stateManager = StateManager()
    
    private let audioCaptureEngine = AudioCaptureEngine()
    private let audioPlayer = AudioPlayer()
    private let wavRecorder = WavRecorder()
    private var orbPhysics = OrbPhysics()
    private var orbRenderer: OrbRenderer?
    private var orbExporter: OrbExporter?
    private let virtualCamera = VirtualCameraOutput()
    
    // Display link for physics updates
    private var displayLink: CVDisplayLink?
    private var physicsTimer: Timer?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current orb state for rendering
    @Published private(set) var orbState = OrbState(
        radialExpansion: 0,
        rippleAmount: 0,
        surfaceTension: 10.0,
        time: 0
    )
    
    // MARK: - Initialization
    
    init() {
        setupDelegates()
        setupPhysicsTimer()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupDelegates() {
        audioCaptureEngine.delegate = self
        audioPlayer.delegate = self
    }
    
    private func setupPhysicsTimer() {
        // Use CVDisplayLink for precise 60Hz timing synchronized with display
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            self.displayLink = displayLink
            
            CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
                guard let userInfo = userInfo else { return kCVReturnSuccess }
                let coordinator = Unmanaged<AuraCoordinator>.fromOpaque(userInfo).takeUnretainedValue()
                DispatchQueue.main.async {
                    coordinator.updatePhysics()
                }
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            
            CVDisplayLinkStart(displayLink)
        } else {
            // Fallback to Timer if CVDisplayLink is unavailable
            physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.updatePhysics()
            }
            physicsTimer?.tolerance = 0.001
        }
    }
    
    private func updatePhysics() {
        orbPhysics.update()
        orbState = orbPhysics.currentState()
        orbRenderer?.updateOrbState(orbState)
    }
    
    // MARK: - Renderer Setup
    
    func setupRenderer(device: MTLDevice) {
        orbRenderer = OrbRenderer(device: device)
        orbExporter = OrbExporter(device: device)
    }
    
    func getRenderer() -> OrbRenderer? {
        return orbRenderer
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard let device = stateManager.selectedDevice else {
            stateManager.setError(.microphoneNotAvailable("No device selected"))
            return
        }
        
        guard stateManager.setRecording(device: device) else {
            return
        }
        
        do {
            // Start audio capture
            try audioCaptureEngine.startCapture(device: device)
            
            // Start WAV recording
            let url = WavRecorder.defaultRecordingURL()
            try wavRecorder.startRecording(to: url)
            
            print("[AuraCoordinator] Recording started to: \(url.path)")
        } catch {
            stateManager.setError(.unknownError(error.localizedDescription))
        }
    }
    
    func stopRecording() {
        audioCaptureEngine.stopCapture()
        
        if let recordedURL = wavRecorder.stopRecording() {
            print("[AuraCoordinator] Recording saved to: \(recordedURL.path)")
        }
        
        stateManager.setIdle()
    }
    
    // MARK: - Playback
    
    func startPlayback(file: URL) {
        guard stateManager.setPlayback(file: file) else {
            return
        }
        
        do {
            try audioPlayer.loadFile(url: file)
            try audioPlayer.play()
            
            print("[AuraCoordinator] Playback started: \(file.lastPathComponent)")
        } catch {
            stateManager.setError(.fileReadError(file.path))
        }
    }
    
    func stopPlayback() {
        audioPlayer.stop()
        stateManager.setIdle()
    }
    
    func pausePlayback() {
        audioPlayer.pause()
    }
    
    func resumePlayback() {
        audioPlayer.resume()
    }
    
    // MARK: - Export
    
    func exportVideo(to outputURL: URL) {
        // Get current recording file for export
        // For now, use a placeholder - actual implementation would track the recorded file
        guard let audioURL = currentAudioFileForExport() else {
            stateManager.setError(.fileReadError("No audio file available"))
            return
        }
        
        guard stateManager.setExporting(file: audioURL) else {
            return
        }
        
        Task {
            do {
                try await orbExporter?.export(audioURL: audioURL, to: outputURL)
                await MainActor.run {
                    stateManager.setIdle()
                }
            } catch {
                await MainActor.run {
                    stateManager.setError(.exportFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func cancelExport() {
        orbExporter?.cancel()
        stateManager.setIdle()
    }
    
    private func currentAudioFileForExport() -> URL? {
        // In a full implementation, track the last recorded or loaded file
        // For now, return nil - would need file tracking
        return nil
    }
    
    // MARK: - Virtual Camera
    
    func toggleVirtualCamera() {
        if virtualCamera.isActive {
            virtualCamera.stop()
            stateManager.setVirtualCameraActive(false)
        } else {
            virtualCamera.start()
            stateManager.setVirtualCameraActive(true)
        }
    }
    
    // MARK: - Device Selection
    
    func selectDevice(_ device: AudioDevice) {
        _ = stateManager.selectDevice(device)
    }
    
    func availableDevices() -> [AudioDevice] {
        return AudioDeviceRegistry.shared.availableInputDevices()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        // Stop CVDisplayLink if active
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
        
        physicsTimer?.invalidate()
        physicsTimer = nil
        
        audioCaptureEngine.stopCapture()
        audioPlayer.stop()
        _ = wavRecorder.stopRecording()
        virtualCamera.stop()
    }
}

// MARK: - AudioCaptureDelegate

extension AuraCoordinator: AudioCaptureDelegate {
    
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didReceiveAnalysis analysis: AudioAnalysis) {
        orbPhysics.applyAudioAnalysis(analysis)
    }
    
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didReceiveBuffer buffer: AVAudioPCMBuffer) {
        if wavRecorder.isActive {
            wavRecorder.writeBuffer(buffer)
        }
    }
}

// MARK: - AudioPlayerDelegate

extension AuraCoordinator: AudioPlayerDelegate {
    
    func audioPlayer(_ player: AudioPlayer, didReceiveAnalysis analysis: AudioAnalysis) {
        orbPhysics.applyAudioAnalysis(analysis)
        stateManager.updatePlaybackPosition(player.currentTime)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer) {
        stateManager.setIdle()
    }
}

// MARK: - OrbExporterDelegate

extension AuraCoordinator: OrbExporterDelegate {
    
    func orbExporter(_ exporter: OrbExporter, didUpdateProgress progress: Float) {
        stateManager.updateExportProgress(progress)
    }
    
    func orbExporter(_ exporter: OrbExporter, didFinishExportTo url: URL) {
        stateManager.setIdle()
        print("[AuraCoordinator] Export completed: \(url.path)")
    }
    
    func orbExporter(_ exporter: OrbExporter, didFailWithError error: Error) {
        stateManager.setError(.exportFailed(error.localizedDescription))
    }
}
