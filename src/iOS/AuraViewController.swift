// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// iOS/AuraViewController.swift — UIKit-based main view controller

#if os(iOS)

import UIKit
import MetalKit
import Combine

// MARK: - AuraViewController (iOS)

/// Main view controller for AURA on iOS.
/// Per ARCHITECTURE.md: UIKit-based, touch and keyboard support.
public final class AuraViewController: UIViewController {
    
    // MARK: - UI Components
    
    private var metalView: MTKView!
    private var statusLabel: UILabel!
    private var durationLabel: UILabel!
    private var recordButton: UIButton!
    private var playButton: UIButton!
    private var stopButton: UIButton!
    private var exportButton: UIButton!
    private var deviceButton: UIButton!
    private var progressView: UIProgressView!
    private var controlsStack: UIStackView!
    
    // MARK: - Coordinator
    
    public var coordinator: AuraCoordinator!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State
    
    private var currentState: AppState = .idle(selectedDevice: nil)
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupCoordinator()
        setupKeyboardCommands()
        
        // Request microphone permission
        coordinator.requestMicrophonePermission { [weak self] granted in
            if !granted {
                self?.showError(.microphonePermissionDenied)
            }
        }
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Dark background
        view.backgroundColor = UIColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
        
        // Metal view for orb rendering
        metalView = MTKView()
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 4
        view.addSubview(metalView)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Ready"
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1.0)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        
        // Duration label
        durationLabel = UILabel()
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.text = "0:00"
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .regular)
        durationLabel.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.91, alpha: 1.0)
        durationLabel.textAlignment = .center
        view.addSubview(durationLabel)
        
        // Progress view
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.progressTintColor = UIColor(red: 0.9, green: 0.9, blue: 0.91, alpha: 1.0)
        view.addSubview(progressView)
        
        // Control buttons
        recordButton = createButton(title: "●", action: #selector(recordButtonTapped))
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        
        playButton = createButton(title: "▶", action: #selector(playButtonTapped))
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        
        stopButton = createButton(title: "■", action: #selector(stopButtonTapped))
        stopButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        
        exportButton = createButton(title: "Export", action: #selector(exportButtonTapped))
        
        deviceButton = createButton(title: "🎤", action: #selector(deviceButtonTapped))
        deviceButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        
        // Controls stack
        controlsStack = UIStackView(arrangedSubviews: [deviceButton, recordButton, playButton, stopButton, exportButton])
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.spacing = 20
        controlsStack.alignment = .center
        controlsStack.distribution = .equalCentering
        view.addSubview(controlsStack)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Metal view (centered, dominant)
            metalView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            metalView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            metalView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            metalView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            metalView.heightAnchor.constraint(equalTo: metalView.widthAnchor, multiplier: 0.75),
            
            // Status label (top)
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Duration label (below metal view)
            durationLabel.topAnchor.constraint(equalTo: metalView.bottomAnchor, constant: 20),
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 10),
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 200),
            
            // Controls stack (bottom)
            controlsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            controlsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Button sizes
            recordButton.widthAnchor.constraint(equalToConstant: 60),
            recordButton.heightAnchor.constraint(equalToConstant: 60),
            playButton.widthAnchor.constraint(equalToConstant: 60),
            playButton.heightAnchor.constraint(equalToConstant: 60),
            stopButton.widthAnchor.constraint(equalToConstant: 60),
            stopButton.heightAnchor.constraint(equalToConstant: 60),
            deviceButton.widthAnchor.constraint(equalToConstant: 60),
            deviceButton.heightAnchor.constraint(equalToConstant: 60),
            exportButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor(red: 0.9, green: 0.9, blue: 0.91, alpha: 1.0), for: .normal)
        button.setTitleColor(UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1.0), for: .disabled)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0).cgColor
        
        return button
    }
    
    // MARK: - Coordinator Setup
    
    private func setupCoordinator() {
        coordinator = AuraCoordinator()
        coordinator.delegate = self
        
        // Configure renderer with metal view
        coordinator.orbRenderer.configure(with: metalView)
        
        // Observe state changes
        coordinator.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateState(state)
            }
            .store(in: &cancellables)
        
        // Observe recording duration
        coordinator.$recordingDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.updateRecordingDuration(duration)
            }
            .store(in: &cancellables)
        
        // Observe playback position
        coordinator.$playbackPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                guard let self = self else { return }
                self.updatePlaybackPosition(position, duration: self.coordinator.playbackDuration)
            }
            .store(in: &cancellables)
        
        // Observe export progress
        coordinator.$exportProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateExportProgress(progress)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Keyboard Commands (iPad)
    
    private func setupKeyboardCommands() {
        // Keyboard commands configured via keyCommands property
    }
    
    public override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []
        
        switch currentState {
        case .idle:
            commands.append(UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleKeyboardSpace)))
            commands.append(UIKeyCommand(input: "o", modifierFlags: .command, action: #selector(handleKeyboardOpen)))
            
        case .recording:
            commands.append(UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleKeyboardSpace)))
            commands.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyboardEscape)))
            
        case .playback:
            commands.append(UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleKeyboardSpace)))
            commands.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyboardEscape)))
            commands.append(UIKeyCommand(input: "e", modifierFlags: .command, action: #selector(handleKeyboardExport)))
            
        case .exporting:
            commands.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyboardEscape)))
            
        case .error:
            commands.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyboardEscape)))
        }
        
        return commands
    }
    
    @objc private func handleKeyboardSpace() {
        switch currentState {
        case .idle: handleStartRecording()
        case .recording: handleStopRecording()
        case .playback: handleTogglePlayback()
        default: break
        }
    }
    
    @objc private func handleKeyboardEscape() {
        switch currentState {
        case .recording: handleCancelRecording()
        case .playback: handleStopPlayback()
        case .exporting: handleCancelExport()
        case .error: coordinator.stateManager.dismissError()
        default: break
        }
    }
    
    @objc private func handleKeyboardOpen() {
        handleOpenFile()
    }
    
    @objc private func handleKeyboardExport() {
        handleExport()
    }
    
    // MARK: - Button Actions
    
    @objc private func recordButtonTapped() {
        if currentState.isRecording {
            handleStopRecording()
        } else {
            handleStartRecording()
        }
    }
    
    @objc private func playButtonTapped() {
        if currentState.isPlayback {
            handleTogglePlayback()
        } else {
            handleOpenFile()
        }
    }
    
    @objc private func stopButtonTapped() {
        if currentState.isRecording {
            handleStopRecording()
        } else if currentState.isPlayback {
            handleStopPlayback()
        }
    }
    
    @objc private func exportButtonTapped() {
        handleExport()
    }
    
    @objc private func deviceButtonTapped() {
        showDevicePicker()
    }
    
    // MARK: - Device Picker
    
    private func showDevicePicker() {
        guard currentState.isIdle else { return }
        
        let alert = UIAlertController(title: "Select Microphone", message: nil, preferredStyle: .actionSheet)
        
        for device in coordinator.availableDevices {
            let title = device.isDefault ? "\(device.name) (Default)" : device.name
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.handleSelectDevice(device)
            }
            
            if device.id == coordinator.stateManager.selectedDevice?.id {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad requires popover presentation
        if let popover = alert.popoverPresentationController {
            popover.sourceView = deviceButton
            popover.sourceRect = deviceButton.bounds
        }
        
        present(alert, animated: true)
    }
}

// MARK: - AuraViewControllerProtocol

extension AuraViewController: AuraViewControllerProtocol {
    
    public func updateState(_ state: AppState) {
        currentState = state
        
        switch state {
        case .idle(let device):
            statusLabel.text = device != nil ? "Ready — \(device!.name)" : "Ready"
            durationLabel.text = "0:00"
            recordButton.setTitle("●", for: .normal)
            recordButton.isEnabled = device != nil
            playButton.setTitle("▶", for: .normal)
            playButton.isEnabled = true
            stopButton.isEnabled = false
            exportButton.isEnabled = false
            deviceButton.isEnabled = true
            progressView.isHidden = true
            
        case .recording(let device, _, _):
            statusLabel.text = "Recording — \(device.name)"
            recordButton.setTitle("■", for: .normal)
            recordButton.isEnabled = true
            playButton.isEnabled = false
            stopButton.isEnabled = true
            exportButton.isEnabled = false
            deviceButton.isEnabled = false
            
        case .playback(let url, _, _, let isPaused):
            statusLabel.text = isPaused ? "Paused" : "Playing"
            recordButton.isEnabled = false
            playButton.setTitle(isPaused ? "▶" : "⏸", for: .normal)
            playButton.isEnabled = true
            stopButton.isEnabled = true
            exportButton.isEnabled = isPaused
            deviceButton.isEnabled = false
            
        case .exporting(_, _, let progress):
            statusLabel.text = "Exporting... \(AuraFormatter.formatProgress(progress))"
            recordButton.isEnabled = false
            playButton.isEnabled = false
            stopButton.isEnabled = false
            exportButton.isEnabled = false
            deviceButton.isEnabled = false
            progressView.isHidden = false
            progressView.progress = progress
            
        case .error(let error):
            showError(error)
        }
    }
    
    public func updateRecordingDuration(_ duration: TimeInterval) {
        durationLabel.text = AuraFormatter.formatDuration(duration)
    }
    
    public func updatePlaybackPosition(_ position: TimeInterval, duration: TimeInterval) {
        durationLabel.text = "\(AuraFormatter.formatDuration(position)) / \(AuraFormatter.formatDuration(duration))"
    }
    
    public func updateExportProgress(_ progress: Float) {
        progressView.progress = progress
    }
    
    public func showError(_ error: AuraError) {
        let alert = UIAlertController(
            title: nil,
            message: error.message,
            preferredStyle: .alert
        )
        
        if let detail = error.detail {
            alert.message = "\(error.message)\n\n\(detail)"
        }
        
        switch error.recovery {
        case .openSettings:
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        case .tryAgain:
            alert.addAction(UIAlertAction(title: "Try Again", style: .default))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        case .chooseFile:
            alert.addAction(UIAlertAction(title: "Choose Another File", style: .default) { [weak self] _ in
                self?.handleOpenFile()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        default:
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        
        present(alert, animated: true)
        coordinator.stateManager.dismissError()
    }
    
    public func updateDeviceList(_ devices: [AudioDevice], selected: AudioDevice?) {
        // Device list is shown in action sheet when deviceButton is tapped
    }
    
    public func handleStartRecording() {
        coordinator.startRecording()
    }
    
    public func handleStopRecording() {
        coordinator.stopRecording()
    }
    
    public func handleCancelRecording() {
        coordinator.cancelRecording()
    }
    
    public func handleStartPlayback(fileURL: URL) {
        coordinator.startPlayback(of: fileURL)
    }
    
    public func handleTogglePlayback() {
        coordinator.togglePlayback()
    }
    
    public func handleStopPlayback() {
        coordinator.stopPlayback()
    }
    
    public func handleExport() {
        guard case .playback(let fileURL, _, _, _) = currentState else { return }
        
        // Generate output URL
        let outputURL = OrbExporter.suggestOutputURL(for: fileURL)
        
        // Start export
        coordinator.startExport(to: outputURL)
    }
    
    public func handleCancelExport() {
        coordinator.cancelExport()
    }
    
    public func handleSelectDevice(_ device: AudioDevice) {
        coordinator.selectDevice(device)
    }
    
    public func handleOpenFile() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.wav, .mp3, .audio])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension AuraViewController: UIDocumentPickerDelegate {
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            showError(.fileNotFound(url: url))
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Copy file to app documents for persistent access
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            coordinator.startPlayback(of: destinationURL)
            
        } catch {
            showError(.fileNotFound(url: url))
        }
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User cancelled
    }
}

// MARK: - AuraCoordinatorDelegate

extension AuraViewController: AuraCoordinatorDelegate {
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didUpdateFeatures features: AudioFeatures) {
        // Features are used by renderer automatically
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didUpdatePlaybackPosition position: TimeInterval, duration: TimeInterval) {
        // Handled by Combine subscription
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didUpdateExportProgress progress: Float) {
        // Handled by Combine subscription
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didEncounterError error: AuraError) {
        showError(error)
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didCompleteRecordingTo fileURL: URL) {
        // Could show notification
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didCompleteExportTo fileURL: URL) {
        // Show share sheet
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // iPad requires popover presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(activityVC, animated: true)
    }
}

#endif
