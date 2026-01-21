import Cocoa

/// Window controller for AURA main window
final class WindowController: NSWindowController {
    
    // MARK: - Properties
    
    var coordinator: AuraCoordinator?
    private var viewController: AuraViewController?
    
    // MARK: - Initialization
    
    convenience init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "AURA"
        window.minSize = NSSize(width: 600, height: 450)
        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
        
        self.init(window: window)
        
        setupViewController()
    }
    
    // MARK: - Setup
    
    private func setupViewController() {
        viewController = AuraViewController()
        viewController?.coordinator = coordinator
        window?.contentViewController = viewController
    }
    
    // MARK: - Coordinator
    
    func setCoordinator(_ coordinator: AuraCoordinator?) {
        self.coordinator = coordinator
        viewController?.coordinator = coordinator
    }
    
    // MARK: - Actions
    
    func showDevicePicker() {
        viewController?.showDevicePicker()
    }
    
    // MARK: - Window Delegate
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Set appearance
        window?.appearance = NSAppearance(named: .darkAqua)
    }
}
