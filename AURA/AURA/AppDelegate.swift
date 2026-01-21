import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var windowController: WindowController?
    private var coordinator: AuraCoordinator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the coordinator
        coordinator = AuraCoordinator()
        
        // Create and show the main window
        windowController = WindowController()
        windowController?.coordinator = coordinator
        windowController?.showWindow(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Safely stop any active recording
        coordinator?.cleanup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Menu Actions
    
    @IBAction func startRecording(_ sender: Any) {
        coordinator?.startRecording()
    }
    
    @IBAction func stopRecording(_ sender: Any) {
        coordinator?.stopRecording()
    }
    
    @IBAction func exportVideo(_ sender: Any) {
        guard let window = windowController?.window else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "AURA-Export.mp4"
        savePanel.canCreateDirectories = true
        
        savePanel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.coordinator?.exportVideo(to: url)
            }
        }
    }
    
    @IBAction func showDevicePicker(_ sender: Any) {
        windowController?.showDevicePicker()
    }
}
