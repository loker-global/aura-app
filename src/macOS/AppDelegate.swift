// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// macOS/AppDelegate.swift — macOS application delegate

#if os(macOS)

import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    var mainWindow: NSWindow!
    var viewController: AuraViewController!
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create main window
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        mainWindow.title = "AURA"
        mainWindow.center()
        mainWindow.setFrameAutosaveName("AURAMainWindow")
        mainWindow.minSize = NSSize(width: 640, height: 480)
        
        // Configure appearance
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.backgroundColor = NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
        mainWindow.appearance = NSAppearance(named: .darkAqua)
        
        // Create view controller
        viewController = AuraViewController()
        mainWindow.contentViewController = viewController
        
        // Setup menu bar
        setupMenuBar()
        
        // Show window
        mainWindow.makeKeyAndOrderFront(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        viewController?.coordinator?.cancelExport()
        viewController?.coordinator?.stopRecording()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "About AURA", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide AURA", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit AURA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        mainMenu.addItem(appMenuItem)
        
        // File menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        
        fileMenu.addItem(NSMenuItem(title: "Open...", action: #selector(openFile), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(closeWindow), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Export Video...", action: #selector(exportVideo), keyEquivalent: "e"))
        
        let exportAudioItem = NSMenuItem(title: "Export Audio...", action: #selector(exportAudio), keyEquivalent: "e")
        exportAudioItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(exportAudioItem)
        
        mainMenu.addItem(fileMenuItem)
        
        // Edit menu (for device settings)
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(NSMenuItem(title: "Input Device...", action: #selector(showDeviceSettings), keyEquivalent: "d"))
        
        mainMenu.addItem(editMenuItem)
        
        // Recording menu
        let recordingMenu = NSMenu(title: "Recording")
        let recordingMenuItem = NSMenuItem()
        recordingMenuItem.submenu = recordingMenu
        
        recordingMenu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: ""))
        recordingMenu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: ""))
        recordingMenu.addItem(NSMenuItem.separator())
        recordingMenu.addItem(NSMenuItem(title: "Cancel Recording", action: #selector(cancelRecording), keyEquivalent: ""))
        
        mainMenu.addItem(recordingMenuItem)
        
        // Playback menu
        let playbackMenu = NSMenu(title: "Playback")
        let playbackMenuItem = NSMenuItem()
        playbackMenuItem.submenu = playbackMenu
        
        playbackMenu.addItem(NSMenuItem(title: "Play/Pause", action: #selector(togglePlayback), keyEquivalent: " "))
        playbackMenu.addItem(NSMenuItem(title: "Stop", action: #selector(stopPlayback), keyEquivalent: ""))
        
        mainMenu.addItem(playbackMenuItem)
        
        // Window menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        
        let fullscreenItem = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullscreenItem.keyEquivalentModifierMask = [.command, .control]
        windowMenu.addItem(fullscreenItem)
        
        mainMenu.addItem(windowMenuItem)
        
        // Help menu
        let helpMenu = NSMenu(title: "Help")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        
        helpMenu.addItem(NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showKeyboardShortcuts), keyEquivalent: "?"))
        
        mainMenu.addItem(helpMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
        NSApplication.shared.windowsMenu = windowMenu
        NSApplication.shared.helpMenu = helpMenu
    }
    
    // MARK: - Menu Actions
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AURA"
        alert.informativeText = "Turn voice into a living fingerprint.\n\nVersion 1.0\n\nLocal-first. No cloud. No accounts.\n\nBuilt with Dr. X protocol."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func openFile() {
        viewController?.handleOpenFile()
    }
    
    @objc private func closeWindow() {
        mainWindow.close()
    }
    
    @objc private func exportVideo() {
        viewController?.handleExport()
    }
    
    @objc private func exportAudio() {
        // Future: audio-only export
    }
    
    @objc private func showDeviceSettings() {
        // Could show device picker modal
    }
    
    @objc private func startRecording() {
        viewController?.handleStartRecording()
    }
    
    @objc private func stopRecording() {
        viewController?.handleStopRecording()
    }
    
    @objc private func cancelRecording() {
        viewController?.handleCancelRecording()
    }
    
    @objc private func togglePlayback() {
        viewController?.handleTogglePlayback()
    }
    
    @objc private func stopPlayback() {
        viewController?.handleStopPlayback()
    }
    
    @objc private func showKeyboardShortcuts() {
        let alert = NSAlert()
        alert.messageText = "AURA Keyboard Shortcuts"
        alert.informativeText = """
        Recording:
        Space / R — Start/Stop Recording
        Esc — Cancel Recording
        
        Playback:
        Space — Play/Pause
        Esc / S — Stop Playback
        
        File:
        ⌘O — Open File
        ⌘E — Export Video
        ⌘⇧E — Export Audio
        
        Other:
        ⌘D — Input Device
        ⌘? — Show Help
        ⌘Q — Quit
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

#endif
