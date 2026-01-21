import Foundation
import CoreMediaIO
import AVFoundation

/// Virtual camera output for streaming orb to other applications
/// Uses CoreMediaIO APIs (macOS 12.3+)
/// No driver or system extension installation required
final class VirtualCameraOutput {
    
    // MARK: - Configuration
    
    struct CameraConfig {
        var width: Int = 1920
        var height: Int = 1080
        var frameRate: Int = 60
    }
    
    // MARK: - Properties
    
    private(set) var isActive = false
    private(set) var consumers: [String] = []
    
    private var cameraConfig = CameraConfig()
    
    // MARK: - Initialization
    
    init() {
        // CoreMediaIO extension setup happens at app level
    }
    
    // MARK: - Control
    
    /// Start virtual camera output
    func start(config: CameraConfig = CameraConfig()) {
        guard !isActive else { return }
        
        cameraConfig = config
        isActive = true
        
        // Note: Full implementation requires CMIOExtension setup
        // This is a placeholder for the Phase 6 virtual camera feature
        print("[VirtualCameraOutput] Started with \(config.width)x\(config.height) @ \(config.frameRate)fps")
    }
    
    /// Stop virtual camera output
    func stop() {
        guard isActive else { return }
        
        isActive = false
        consumers = []
        
        print("[VirtualCameraOutput] Stopped")
    }
    
    /// Send frame to virtual camera
    func sendFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard isActive else { return }
        
        // Note: Full implementation sends to CMIOExtensionStreamSource
        // This is a placeholder for the Phase 6 virtual camera feature
    }
    
    /// Update list of apps consuming the camera feed
    func updateConsumers(_ appNames: [String]) {
        consumers = appNames
    }
}

// MARK: - Status

extension VirtualCameraOutput {
    
    /// Status description for UI
    var statusDescription: String {
        if !isActive {
            return "Off"
        } else if consumers.isEmpty {
            return "Active"
        } else {
            return "In Use by \(consumers.joined(separator: ", "))"
        }
    }
}
