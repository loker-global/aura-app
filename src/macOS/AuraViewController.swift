// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// macOS/AuraViewController.swift — AppKit-based main view controller

#if os(macOS)

import AppKit
import MetalKit
import Combine

// MARK: - AuraViewController (macOS)

/// Main view controller for AURA on macOS.
/// Per ARCHITECTURE.md: AppKit-based, keyboard-first, menu bar integration.
public final class AuraViewController: NSViewController {
    
    // MARK: - UI Components
    
    private var metalView: MTKView!
    private var statusLabel: NSTextField!
    private var durationLabel: NSTextField!
    private var devicePopup: NSPopUpButton!
    private var recordButton: NSButton!
    private var playButton: NSButton!
    private var stopButton: NSButton!
    private var exportButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    // MARK: - Coordinator
    
    public var coordinator: AuraCoordinator!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State
    
    private var currentState: AppState = .idle(selectedDevice: nil)
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        // Create main view with dark background
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0).cgColor
        self.view = mainView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupCoordinator()
        setupKeyboardShortcuts()
        
        // Request microphone permission
        coordinator.requestMicrophonePermission { [weak self] granted in
            if !granted {
                self?.showError(.microphonePermissionDenied)
            }
        }
    }
    
    public override func viewWillAppear() {
        super.viewWillAppear()
        
        // Configure window
        view.window?.title = "AURA"
        view.window?.styleMask.insert(.fullSizeContentView)
        view.window?.titlebarAppearsTransparent = true
        view.window?.backgroundColor = NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Metal view for orb rendering (centered, dominant)
        metalView = MTKView(frame: NSRect(x: 100, y: 100, width: 600, height: 400))
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 4
        view.addSubview(metalView)
        
        // Status label
        statusLabel = createLabel(text: "Ready", fontSize: 14)
        statusLabel.textColor = NSColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1.0)
        view.addSubview(statusLabel)
        
        // Duration label
        durationLabel = createLabel(text: "0:00", fontSize: 24)
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .regular)
        durationLabel.textColor = NSColor(red: 0.9, green: 0.9, blue: 0.91, alpha: 1.0)
        view.addSubview(durationLabel)
        
        // Device popup
        devicePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        devicePopup.translatesAutoresizingMaskIntoConstraints = false
        devicePopup.target = self
        devicePopup.action = #selector(deviceSelected)
        view.addSubview(devicePopup)
        
        // Control buttons
        recordButton = createButton(title: "● Record", action: #selector(recordButtonPressed))
        playButton = createButton(title: "▶ Play", action: #selector(playButtonPressed))
        stopButton = createButton(title: "■ Stop", action: #selector(stopButtonPressed))
        exportButton = createButton(title: "Export", action: #selector(exportButtonPressed))
        
        view.addSubview(recordButton)
        view.addSubview(playButton)
        view.addSubview(stopButton)
        view.addSubview(exportButton)
        
        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.isHidden = true
        view.addSubview(progressIndicator)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Metal view (centered, dominant)
            metalView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            metalView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            metalView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            metalView.heightAnchor.constraint(equalTo: metalView.widthAnchor, multiplier: 0.75),
            
            // Device popup (top right)
            devicePopup.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            devicePopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            devicePopup.widthAnchor.constraint(equalToConstant: 200),
            
            // Status label (top left)
            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 55),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Duration label (bottom center, above controls)
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            durationLabel.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -20),
            
            // Control buttons (bottom center)
            recordButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            recordButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -60),
            
            playButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            playButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: -50),
            
            stopButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            stopButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            
            exportButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            exportButton.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 10),
            
            // Progress indicator
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.bottomAnchor.constraint(equalTo: durationLabel.topAnchor, constant: -10),
            progressIndicator.widthAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func createLabel(text: String, fontSize: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.alignment = .center
        return label
    }
    
    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .large
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
        
        // Update device list
        updateDeviceList(coordinator.availableDevices, selected: coordinator.stateManager.selectedDevice)
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        // Keyboard events are handled in keyDown
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        
        switch currentState {
        case .idle:
            if keyCode == 49 { // Space
                handleStartRecording()
            } else if event.charactersIgnoringModifiers == "r" {
                handleStartRecording()
            } else if modifiers.contains(.command) {
                if event.charactersIgnoringModifiers == "o" {
                    handleOpenFile()
                } else if event.charactersIgnoringModifiers == "d" {
                    // Focus device popup
                    devicePopup.performClick(nil)
                }
            }
            
        case .recording:
            if keyCode == 49 || event.charactersIgnoringModifiers == "r" {
                handleStopRecording()
            } else if keyCode == 53 { // Esc
                handleCancelRecording()
            }
            
        case .playback:
            if keyCode == 49 { // Space
                handleTogglePlayback()
            } else if keyCode == 53 || event.charactersIgnoringModifiers == "s" { // Esc or S
                handleStopPlayback()
            } else if modifiers.contains(.command) {
                if event.charactersIgnoringModifiers == "e" {
                    if modifiers.contains(.shift) {
                        // Export audio (future)
                    } else {
                        handleExport()
                    }
                }
            }
            
        case .exporting:
            if keyCode == 53 { // Esc
                handleCancelExport()
            }
            
        case .error:
            if keyCode == 53 { // Esc
                coordinator.stateManager.dismissError()
            }
        }
        
        // Help shortcut
        if modifiers.contains(.command) && event.charactersIgnoringModifiers == "?" {
            showHelpOverlay()
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func recordButtonPressed() {
        if currentState.isRecording {
            handleStopRecording()
        } else {
            handleStartRecording()
        }
    }
    
    @objc private func playButtonPressed() {
        if currentState.isPlayback {
            handleTogglePlayback()
        } else {
            handleOpenFile()
        }
    }
    
    @objc private func stopButtonPressed() {
        if currentState.isRecording {
            handleStopRecording()
        } else if currentState.isPlayback {
            handleStopPlayback()
        }
    }
    
    @objc private func exportButtonPressed() {
        handleExport()
    }
    
    @objc private func deviceSelected() {
        guard let selectedItem = devicePopup.selectedItem,
              let device = coordinator.availableDevices.first(where: { $0.name == selectedItem.title }) else {
            return
        }
        handleSelectDevice(device)
    }
    
    // MARK: - Help Overlay
    
    private func showHelpOverlay() {
        let shortcuts = KeyboardShortcut.shortcuts(for: currentState)
        var helpText = "Keyboard Shortcuts:\n\n"
        
        for shortcut in shortcuts {
            switch shortcut {
            case .startRecording: helpText += "Space / R — Start Recording\n"
            case .stopRecording: helpText += "Space / R — Stop Recording\n"
            case .cancelRecording: helpText += "Esc — Cancel Recording\n"
            case .togglePlayback: helpText += "Space — Play/Pause\n"
            case .stopPlayback: helpText += "Esc / S — Stop Playback\n"
            case .cancelExport: helpText += "Esc — Cancel Export\n"
            case .openFile: helpText += "⌘O — Open File\n"
            case .exportVideo: helpText += "⌘E — Export Video\n"
            case .exportAudio: helpText += "⌘⇧E — Export Audio\n"
            case .deviceSettings: helpText += "⌘D — Device Settings\n"
            case .showHelp: helpText += "⌘? — Show Help\n"
            default: break
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "AURA Keyboard Shortcuts"
        alert.informativeText = helpText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - AuraViewControllerProtocol

extension AuraViewController: AuraViewControllerProtocol {
    
    public func updateState(_ state: AppState) {
        currentState = state
        
        switch state {
        case .idle(let device):
            statusLabel.stringValue = device != nil ? "Ready — \(device!.name)" : "Ready"
            durationLabel.stringValue = "0:00"
            recordButton.title = "● Record"
            recordButton.isEnabled = device != nil
            playButton.title = "▶ Play"
            playButton.isEnabled = true
            stopButton.isEnabled = false
            exportButton.isEnabled = false
            devicePopup.isEnabled = true
            progressIndicator.isHidden = true
            
        case .recording(let device, _, _):
            statusLabel.stringValue = "Recording — \(device.name)"
            recordButton.title = "■ Stop"
            recordButton.isEnabled = true
            playButton.isEnabled = false
            stopButton.isEnabled = true
            exportButton.isEnabled = false
            devicePopup.isEnabled = false
            
        case .playback(let url, _, _, let isPaused):
            statusLabel.stringValue = isPaused ? "Paused — \(url.lastPathComponent)" : "Playing — \(url.lastPathComponent)"
            recordButton.isEnabled = false
            playButton.title = isPaused ? "▶ Play" : "⏸ Pause"
            playButton.isEnabled = true
            stopButton.isEnabled = true
            exportButton.isEnabled = isPaused
            devicePopup.isEnabled = false
            
        case .exporting(_, _, let progress):
            statusLabel.stringValue = "Exporting... \(AuraFormatter.formatProgress(progress))"
            recordButton.isEnabled = false
            playButton.isEnabled = false
            stopButton.isEnabled = false
            exportButton.isEnabled = false
            devicePopup.isEnabled = false
            progressIndicator.isHidden = false
            progressIndicator.doubleValue = Double(progress * 100)
            
        case .error(let error):
            showError(error)
        }
    }
    
    public func updateRecordingDuration(_ duration: TimeInterval) {
        durationLabel.stringValue = AuraFormatter.formatDuration(duration)
    }
    
    public func updatePlaybackPosition(_ position: TimeInterval, duration: TimeInterval) {
        durationLabel.stringValue = "\(AuraFormatter.formatDuration(position)) / \(AuraFormatter.formatDuration(duration))"
    }
    
    public func updateExportProgress(_ progress: Float) {
        progressIndicator.doubleValue = Double(progress * 100)
    }
    
    public func showError(_ error: AuraError) {
        let alert = NSAlert()
        alert.messageText = error.message
        if let detail = error.detail {
            alert.informativeText = detail
        }
        alert.alertStyle = .warning
        
        switch error.recovery {
        case .openSettings:
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        case .tryAgain:
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Cancel")
        case .chooseFile:
            alert.addButton(withTitle: "Choose Another File")
            alert.addButton(withTitle: "Cancel")
        case .chooseLocation:
            alert.addButton(withTitle: "Choose Folder")
            alert.addButton(withTitle: "Cancel")
        case .useBuiltInMic:
            alert.addButton(withTitle: "Use Built-in Mic")
            alert.addButton(withTitle: "Cancel")
        case .none, nil:
            alert.addButton(withTitle: "OK")
        }
        
        let response = alert.runModal()
        
        // Handle recovery actions
        if response == .alertFirstButtonReturn {
            switch error.recovery {
            case .openSettings:
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            case .tryAgain:
                // Retry based on context
                break
            case .chooseFile:
                handleOpenFile()
            case .chooseLocation:
                // Show save panel
                break
            case .useBuiltInMic:
                if let device = coordinator.availableDevices.first(where: { $0.deviceType == .builtIn }) {
                    handleSelectDevice(device)
                }
            case .none, nil:
                break
            }
        }
        
        coordinator.stateManager.dismissError()
    }
    
    public func updateDeviceList(_ devices: [AudioDevice], selected: AudioDevice?) {
        devicePopup.removeAllItems()
        
        for device in devices {
            let title = device.isDefault ? "\(device.name) (Default)" : device.name
            devicePopup.addItem(withTitle: title)
        }
        
        if let selected = selected,
           let index = devices.firstIndex(where: { $0.id == selected.id }) {
            devicePopup.selectItem(at: index)
        }
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
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".mp4"
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        
        savePanel.beginSheetModal(for: view.window!) { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.coordinator.startExport(to: url)
            }
        }
    }
    
    public func handleCancelExport() {
        coordinator.cancelExport()
    }
    
    public func handleSelectDevice(_ device: AudioDevice) {
        coordinator.selectDevice(device)
    }
    
    public func handleOpenFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.wav, .mp3, .audio]
        openPanel.allowsMultipleSelection = false
        
        if let recordingsDir = try? WavRecorder.recordingsDirectory() {
            openPanel.directoryURL = recordingsDir
        }
        
        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.coordinator.startPlayback(of: url)
            }
        }
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
        // Could show notification or auto-play
        NSSound.beep()
    }
    
    public func auraCoordinator(_ coordinator: AuraCoordinator, didCompleteExportTo fileURL: URL) {
        // Reveal in Finder
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

#endif
