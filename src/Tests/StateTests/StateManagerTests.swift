// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// Tests/StateTests/StateManagerTests.swift

import XCTest
@testable import AURA

@MainActor
final class StateManagerTests: XCTestCase {
    
    var stateManager: StateManager!
    var testDevice: AudioDevice!
    
    override func setUp() {
        super.setUp()
        
        testDevice = AudioDevice(
            id: "test-device-1",
            name: "Test Microphone",
            sampleRate: 48000,
            channelCount: 1,
            deviceType: .builtIn,
            isDefault: true
        )
        
        stateManager = StateManager(initialDevice: testDevice)
    }
    
    override func tearDown() {
        stateManager = nil
        testDevice = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Should start in idle state with device
        XCTAssertTrue(stateManager.currentState.isIdle)
        XCTAssertEqual(stateManager.selectedDevice?.id, testDevice.id)
    }
    
    func testInitialStateWithNoDevice() {
        let manager = StateManager(initialDevice: nil)
        
        XCTAssertTrue(manager.currentState.isIdle)
        XCTAssertNil(manager.selectedDevice)
    }
    
    // MARK: - Recording State Transitions
    
    func testStartRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        let result = stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isRecording)
    }
    
    func testStopRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        let result = stateManager.apply(.stopRecording)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testCancelRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        let result = stateManager.apply(.cancelRecording)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testCannotStartRecordingWithoutDevice() {
        let manager = StateManager(initialDevice: nil)
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        let result = manager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        // Should fail because no device is selected in idle state
        XCTAssertFalse(result)
    }
    
    // MARK: - Playback State Transitions
    
    func testStartPlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        let result = stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isPlayback)
    }
    
    func testPausePlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        
        let result = stateManager.apply(.pausePlayback)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isPlaybackPaused)
    }
    
    func testResumePlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        stateManager.apply(.pausePlayback)
        
        let result = stateManager.apply(.resumePlayback)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isPlayback)
        XCTAssertFalse(stateManager.currentState.isPlaybackPaused)
    }
    
    func testStopPlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        
        let result = stateManager.apply(.stopPlayback)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testSeekPlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        
        let result = stateManager.apply(.seekPlayback(position: 30.0))
        
        XCTAssertTrue(result)
        
        if case .playback(_, let position, _, _) = stateManager.currentState {
            XCTAssertEqual(position, 30.0)
        } else {
            XCTFail("Should be in playback state")
        }
    }
    
    // MARK: - Export State Transitions
    
    func testStartExport() {
        let sourceURL = URL(fileURLWithPath: "/tmp/test.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        stateManager.apply(.startPlayback(fileURL: sourceURL, duration: 60.0))
        
        let result = stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isExporting)
    }
    
    func testUpdateExportProgress() {
        let sourceURL = URL(fileURLWithPath: "/tmp/test.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        stateManager.apply(.startPlayback(fileURL: sourceURL, duration: 60.0))
        stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        let result = stateManager.apply(.updateExportProgress(progress: 0.5))
        
        XCTAssertTrue(result)
        
        if case .exporting(_, _, let progress) = stateManager.currentState {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Should be in exporting state")
        }
    }
    
    func testCompleteExport() {
        let sourceURL = URL(fileURLWithPath: "/tmp/test.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        stateManager.apply(.startPlayback(fileURL: sourceURL, duration: 60.0))
        stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        let result = stateManager.apply(.completeExport)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isPlayback)
    }
    
    func testCancelExport() {
        let sourceURL = URL(fileURLWithPath: "/tmp/test.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        stateManager.apply(.startPlayback(fileURL: sourceURL, duration: 60.0))
        stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        let result = stateManager.apply(.cancelExport)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isPlayback)
    }
    
    // MARK: - Device Selection Tests
    
    func testSelectDevice() {
        let newDevice = AudioDevice(
            id: "test-device-2",
            name: "USB Microphone",
            sampleRate: 48000,
            channelCount: 1,
            deviceType: .usb,
            isDefault: false
        )
        
        let result = stateManager.apply(.selectDevice(device: newDevice))
        
        XCTAssertTrue(result)
        XCTAssertEqual(stateManager.selectedDevice?.id, newDevice.id)
    }
    
    func testCannotSwitchDeviceDuringRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        let newDevice = AudioDevice(
            id: "test-device-2",
            name: "USB Microphone",
            sampleRate: 48000,
            channelCount: 1,
            deviceType: .usb,
            isDefault: false
        )
        
        let result = stateManager.apply(.selectDevice(device: newDevice))
        
        XCTAssertFalse(result)
    }
    
    // MARK: - Error State Tests
    
    func testReportError() {
        let error = AuraError.microphonePermissionDenied
        
        let result = stateManager.apply(.reportError(error: error))
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isError)
    }
    
    func testDismissError() {
        stateManager.apply(.reportError(error: .microphonePermissionDenied))
        
        let result = stateManager.apply(.dismissError)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    // MARK: - Invalid Transition Tests
    
    func testInvalidTransitionFromRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        // Cannot start playback while recording
        let result = stateManager.apply(.startPlayback(fileURL: fileURL, duration: 60.0))
        
        XCTAssertFalse(result)
        XCTAssertTrue(stateManager.currentState.isRecording)
    }
    
    func testInvalidTransitionFromExporting() {
        let sourceURL = URL(fileURLWithPath: "/tmp/test.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        stateManager.apply(.startPlayback(fileURL: sourceURL, duration: 60.0))
        stateManager.apply(.startExport(sourceURL: sourceURL, outputURL: outputURL))
        
        // Cannot start recording while exporting
        let result = stateManager.apply(.startRecording(device: testDevice, fileURL: sourceURL))
        
        XCTAssertFalse(result)
        XCTAssertTrue(stateManager.currentState.isExporting)
    }
    
    // MARK: - Convenience Method Tests
    
    func testConvenienceStartRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        let result = stateManager.startRecording(to: fileURL)
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isRecording)
    }
    
    func testConvenienceStopRecording() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.startRecording(to: fileURL)
        
        let result = stateManager.stopRecording()
        
        XCTAssertTrue(result)
        XCTAssertTrue(stateManager.currentState.isIdle)
    }
    
    func testConvenienceTogglePlayback() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.startPlayback(of: fileURL, duration: 60.0)
        
        // Toggle to pause
        stateManager.togglePlayback()
        XCTAssertTrue(stateManager.currentState.isPlaybackPaused)
        
        // Toggle to resume
        stateManager.togglePlayback()
        XCTAssertFalse(stateManager.currentState.isPlaybackPaused)
    }
    
    // MARK: - State History Tests
    
    func testStateHistory() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        stateManager.apply(.stopRecording)
        
        // Should have: initial idle, recording, idle
        XCTAssertEqual(stateManager.stateHistory.count, 3)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        stateManager.apply(.startRecording(device: testDevice, fileURL: fileURL))
        
        stateManager.reset(device: testDevice)
        
        XCTAssertTrue(stateManager.currentState.isIdle)
        XCTAssertEqual(stateManager.selectedDevice?.id, testDevice.id)
    }
}
