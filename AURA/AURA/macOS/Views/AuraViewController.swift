import Cocoa
import Metal
import MetalKit
import Combine

/// Main view controller for AURA (macOS)
/// AppKit-based, wraps OrbRenderer in NSView
/// Implements keyboard shortcuts
final class AuraViewController: NSViewController {
    
    // MARK: - Properties
    
    var coordinator: AuraCoordinator?
    
    private var metalView: MTKView!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    
    // UI Elements
    private var recordingIndicator: NSView!
    private var statusLabel: NSTextField!
    private var durationLabel: NSTextField!
    private var durationTimer: Timer?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        // Create main view
        let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0).cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetalView()
        setupUI()
        setupBindings()
        setupKeyboardHandling()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }
    
    // MARK: - Setup
    
    private func setupMetalView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            showError(AuraError.unknownError("Metal is not supported on this device"))
            return
        }
        
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView)
        
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Setup renderer
        coordinator?.setupRenderer(device: device)
        coordinator?.getRenderer()?.configure(view: metalView)
    }
    
    private func setupUI() {
        // Recording indicator (small red dot, hidden by default)
        recordingIndicator = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
        recordingIndicator.wantsLayer = true
        recordingIndicator.layer?.backgroundColor = NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
        recordingIndicator.layer?.cornerRadius = 6
        recordingIndicator.isHidden = true
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordingIndicator)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Duration label
        durationLabel = NSTextField(labelWithString: "")
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = NSColor(white: 0.9, alpha: 1.0)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(durationLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            recordingIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            recordingIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            durationLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            durationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupBindings() {
        coordinator?.stateManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        coordinator?.$orbState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.coordinator?.getRenderer()?.updateOrbState(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupKeyboardHandling() {
        // Enable key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUI(for state: AppState) {
        switch state {
        case .idle:
            recordingIndicator.isHidden = true
            statusLabel.stringValue = "Ready"
            durationLabel.stringValue = ""
            stopDurationTimer()
            
        case .recording:
            recordingIndicator.isHidden = false
            statusLabel.stringValue = "Recording"
            startDurationTimer()
            
        case .playback(_, let position):
            recordingIndicator.isHidden = true
            statusLabel.stringValue = "Playing"
            durationLabel.stringValue = formatDuration(position)
            
        case .exporting(_, let progress):
            recordingIndicator.isHidden = true
            statusLabel.stringValue = "Exporting..."
            durationLabel.stringValue = "\(Int(progress * 100))%"
            
        case .error(let error):
            recordingIndicator.isHidden = true
            statusLabel.stringValue = error.title
            showError(error)
        }
    }
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let duration = self?.coordinator?.stateManager.recordingDuration else { return }
            self?.durationLabel.stringValue = self?.formatDuration(duration) ?? ""
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, secs, tenths)
    }
    
    // MARK: - Keyboard Handling (from KEYBOARD-SHORTCUTS.md)
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let characters = event.charactersIgnoringModifiers else { return event }
        
        let state = coordinator?.stateManager.currentState ?? .idle(selectedDevice: nil)
        
        switch characters {
        case " ":  // Space: Start/Stop recording
            if state.isRecording {
                coordinator?.stopRecording()
            } else if state.isIdle {
                coordinator?.startRecording()
            }
            return nil
            
        case "\u{1B}":  // Escape: Stop current action
            if state.isRecording {
                coordinator?.stopRecording()
            } else if state.isPlayback {
                coordinator?.stopPlayback()
            } else if state.isExporting {
                coordinator?.cancelExport()
            }
            return nil
            
        default:
            break
        }
        
        // Handle Command shortcuts
        if event.modifierFlags.contains(.command) {
            switch characters {
            case "r":  // Cmd+R: Start recording
                if state.isIdle {
                    coordinator?.startRecording()
                }
                return nil
                
            case ".":  // Cmd+.: Stop recording
                if state.isRecording {
                    coordinator?.stopRecording()
                }
                return nil
                
            case "d":  // Cmd+D: Device picker
                showDevicePicker()
                return nil
                
            default:
                break
            }
        }
        
        return event
    }
    
    // MARK: - Device Picker
    
    func showDevicePicker() {
        let devices = coordinator?.availableDevices() ?? []
        
        let menu = NSMenu(title: "Select Audio Device")
        
        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device
            
            if device == coordinator?.stateManager.selectedDevice {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        // Show menu at bottom left
        let location = NSPoint(x: 20, y: 40)
        menu.popUp(positioning: nil, at: location, in: view)
    }
    
    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        coordinator?.selectDevice(device)
    }
    
    // MARK: - Error Handling
    
    private func showError(_ error: AuraError) {
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if case .microphonePermissionDenied = error {
            alert.addButton(withTitle: "Open System Preferences")
        }
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Return to idle state
        coordinator?.stateManager.setIdle()
    }
    
    // MARK: - First Responder
    
    override var acceptsFirstResponder: Bool { true }
}
