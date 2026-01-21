import XCTest
@testable import AURA

final class AURATests: XCTestCase {
    
    func testStateManagerInitialization() {
        let stateManager = StateManager()
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testStateTransitions() {
        let stateManager = StateManager()
        
        // Create mock device
        let device = AudioDevice(
            id: 1,
            name: "Test Microphone",
            manufacturer: "Test",
            sampleRate: 48000.0,
            channelCount: 1,
            isDefault: true
        )
        
        // Test recording transition
        _ = stateManager.selectDevice(device)
        XCTAssertTrue(stateManager.setRecording(device: device))
        XCTAssertTrue(stateManager.currentState.isRecording)
        
        // Test cannot switch device while recording
        XCTAssertFalse(stateManager.selectDevice(device))
        
        // Test return to idle
        stateManager.setIdle()
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testErrorStates() {
        let stateManager = StateManager()
        
        stateManager.setError(.microphonePermissionDenied)
        XCTAssertTrue(stateManager.currentState.isError)
        
        stateManager.setIdle()
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
}
