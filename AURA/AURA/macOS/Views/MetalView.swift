import Cocoa
import MetalKit
import Metal

/// Metal view wrapper for NSView
/// Subclass of NSView containing MTKView
final class MetalView: NSView {
    
    // MARK: - Properties
    
    private(set) var mtkView: MTKView!
    private var renderer: OrbRenderer?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMetal()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }
    
    // MARK: - Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[MetalView] Metal is not supported")
            return
        }
        
        // Create MTKView
        mtkView = MTKView(frame: bounds, device: device)
        mtkView.autoresizingMask = [.width, .height]
        addSubview(mtkView)
        
        // Create renderer
        renderer = OrbRenderer(device: device)
        renderer?.configure(view: mtkView)
    }
    
    // MARK: - Renderer Access
    
    func getRenderer() -> OrbRenderer? {
        return renderer
    }
    
    func updateOrbState(_ state: OrbState) {
        renderer?.updateOrbState(state)
    }
}
