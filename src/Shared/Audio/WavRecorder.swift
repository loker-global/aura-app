// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// WavRecorder.swift — Deterministic WAV file writer

import AVFoundation

// MARK: - WavRecorderDelegate

/// Delegate for receiving recording events.
public protocol WavRecorderDelegate: AnyObject {
    /// Called when recording starts successfully.
    func wavRecorderDidStartRecording(_ recorder: WavRecorder, fileURL: URL)
    
    /// Called when recording stops (with final file URL).
    func wavRecorderDidStopRecording(_ recorder: WavRecorder, fileURL: URL, duration: TimeInterval)
    
    /// Called when an error occurs during recording.
    func wavRecorder(_ recorder: WavRecorder, didEncounterError error: WavRecorderError)
}

// MARK: - WavRecorderError

/// Errors that can occur during WAV recording.
public enum WavRecorderError: Error, LocalizedError {
    case fileCreationFailed(String)
    case diskFull
    case writeFailed
    case invalidFormat
    case alreadyRecording
    case notRecording
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .fileCreationFailed(let path):
            return "Could not create recording file at \(path)."
        case .diskFull:
            return "Recording stopped. Disk is full."
        case .writeFailed:
            return "Failed to write audio data."
        case .invalidFormat:
            return "Invalid audio format."
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording in progress."
        case .permissionDenied:
            return "Cannot save to this location. Choose a different folder."
        }
    }
}

// MARK: - WavRecorder

/// Deterministic WAV file writer.
/// Per ARCHITECTURE.md: Single responsibility - audio → disk.
///
/// WAV Format (per FILE-MANAGEMENT.md):
/// - Container: WAV (RIFF WAVE)
/// - Codec: PCM (uncompressed)
/// - Sample Rate: 48 kHz (or source rate)
/// - Bit Depth: 16-bit
/// - Channels: 1 (mono)
///
/// Thread Safety: All write operations are dispatched to a dedicated I/O queue.
public final class WavRecorder {
    
    // MARK: - Configuration
    
    /// Recording directory name
    public static let recordingsDirectoryName = "Recordings"
    
    /// File name format: Voice_YYYYMMDD_HHMMSS.wav
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    // MARK: - Properties
    
    /// Whether recording is in progress
    public private(set) var isRecording = false
    
    /// Current recording file URL
    public private(set) var currentFileURL: URL?
    
    /// Recording start time
    public private(set) var startTime: Date?
    
    /// Total samples written
    public private(set) var samplesWritten: Int64 = 0
    
    /// Sample rate of current recording
    public private(set) var sampleRate: Double = 48000
    
    /// Delegate for recording events
    public weak var delegate: WavRecorderDelegate?
    
    // MARK: - Private Properties
    
    private var audioFile: AVAudioFile?
    private let ioQueue = DispatchQueue(label: "com.aura.wavRecorder.io", qos: .userInitiated)
    
    // Periodic header update interval (samples)
    private static let headerUpdateInterval: Int64 = 48000 * 10 // Every 10 seconds
    private var lastHeaderUpdate: Int64 = 0
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Gets the recordings directory URL, creating it if needed.
    /// - Parameter createIfNeeded: Whether to create the directory if it doesn't exist
    /// - Returns: URL to recordings directory
    public static func recordingsDirectory(createIfNeeded: Bool = true) throws -> URL {
        #if os(macOS)
        // Primary: ~/Documents/AURA/Recordings/
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let auraDirectory = documentsURL.appendingPathComponent("AURA", isDirectory: true)
        #else
        // iOS: App Documents directory
        let auraDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
        
        let recordingsURL = auraDirectory.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        
        if createIfNeeded && !FileManager.default.fileExists(atPath: recordingsURL.path) {
            try FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700 // User read/write/execute only
            ])
        }
        
        return recordingsURL
    }
    
    /// Generates a unique filename for a new recording.
    /// Format: Voice_YYYYMMDD_HHMMSS.wav
    /// Handles collisions by appending counter: Voice_YYYYMMDD_HHMMSS_1.wav
    public static func generateFilename(in directory: URL) -> URL {
        let timestamp = dateFormatter.string(from: Date())
        let baseName = "Voice_\(timestamp)"
        var filename = "\(baseName).wav"
        var counter = 1
        var fileURL = directory.appendingPathComponent(filename)
        
        // Handle collision (max 100 attempts)
        while FileManager.default.fileExists(atPath: fileURL.path) && counter <= 100 {
            filename = "\(baseName)_\(counter).wav"
            fileURL = directory.appendingPathComponent(filename)
            counter += 1
        }
        
        return fileURL
    }
    
    /// Starts recording to a new WAV file.
    /// - Parameters:
    ///   - format: Audio format for recording
    ///   - directory: Optional custom directory (defaults to standard recordings directory)
    /// - Throws: WavRecorderError if recording cannot start
    public func startRecording(format: AVAudioFormat, directory: URL? = nil) throws {
        guard !isRecording else {
            throw WavRecorderError.alreadyRecording
        }
        
        // Get recordings directory
        let recordingsDir: URL
        if let customDir = directory {
            recordingsDir = customDir
        } else {
            recordingsDir = try Self.recordingsDirectory(createIfNeeded: true)
        }
        
        // Generate unique filename
        let fileURL = Self.generateFilename(in: recordingsDir)
        
        // Create audio file with WAV format settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1, // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        // Create output format (mono, 16-bit PCM)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: format.sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw WavRecorderError.invalidFormat
        }
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            throw WavRecorderError.fileCreationFailed(fileURL.path)
        }
        
        // Set recording state
        currentFileURL = fileURL
        startTime = Date()
        sampleRate = format.sampleRate
        samplesWritten = 0
        lastHeaderUpdate = 0
        isRecording = true
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.wavRecorderDidStartRecording(self, fileURL: fileURL)
        }
    }
    
    /// Writes an audio buffer to the recording file.
    /// Thread-safe: can be called from audio thread.
    /// - Parameter buffer: Audio buffer to write
    public func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let audioFile = audioFile else { return }
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Convert to mono if needed (use first channel)
                let monoBuffer: AVAudioPCMBuffer
                if buffer.format.channelCount > 1 {
                    monoBuffer = self.convertToMono(buffer)
                } else {
                    monoBuffer = buffer
                }
                
                // Write buffer to file
                try audioFile.write(from: monoBuffer)
                
                // Update samples written
                self.samplesWritten += Int64(monoBuffer.frameLength)
                
                // Periodically update header for partial file safety
                if self.samplesWritten - self.lastHeaderUpdate >= Self.headerUpdateInterval {
                    // The AVAudioFile handles this automatically, but we track for logging
                    self.lastHeaderUpdate = self.samplesWritten
                }
                
            } catch {
                // Check for disk full error
                if (error as NSError).domain == NSCocoaErrorDomain &&
                   (error as NSError).code == NSFileWriteOutOfSpaceError {
                    self.handleDiskFull()
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.wavRecorder(self, didEncounterError: .writeFailed)
                    }
                }
            }
        }
    }
    
    /// Stops recording and finalizes the file.
    public func stopRecording() {
        guard isRecording else { return }
        
        ioQueue.sync { [weak self] in
            guard let self = self else { return }
            
            // Close the audio file (this finalizes the WAV header)
            self.audioFile = nil
            
            let duration = self.recordingDuration
            let fileURL = self.currentFileURL
            
            // Reset state
            self.isRecording = false
            
            // Notify delegate on main thread
            DispatchQueue.main.async {
                if let url = fileURL {
                    self.delegate?.wavRecorderDidStopRecording(self, fileURL: url, duration: duration)
                }
            }
        }
    }
    
    /// Cancels recording and deletes the file.
    public func cancelRecording() {
        guard isRecording else { return }
        
        ioQueue.sync { [weak self] in
            guard let self = self else { return }
            
            // Close and delete the file
            self.audioFile = nil
            
            if let fileURL = self.currentFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            // Reset state
            self.isRecording = false
            self.currentFileURL = nil
            self.samplesWritten = 0
        }
    }
    
    /// Current recording duration in seconds.
    public var recordingDuration: TimeInterval {
        guard samplesWritten > 0, sampleRate > 0 else { return 0 }
        return TimeInterval(samplesWritten) / sampleRate
    }
    
    // MARK: - Private Methods
    
    private func convertToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let monoFormat = AVAudioFormat(
            commonFormat: buffer.format.commonFormat,
            sampleRate: buffer.format.sampleRate,
            channels: 1,
            interleaved: buffer.format.isInterleaved
        ),
        let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        
        monoBuffer.frameLength = buffer.frameLength
        
        // Mix down to mono (average channels) or just take first channel
        if let srcData = buffer.floatChannelData, let dstData = monoBuffer.floatChannelData {
            let frameCount = Int(buffer.frameLength)
            
            if buffer.format.channelCount == 2 {
                // Average left and right
                for i in 0..<frameCount {
                    dstData[0][i] = (srcData[0][i] + srcData[1][i]) / 2.0
                }
            } else {
                // Just copy first channel
                memcpy(dstData[0], srcData[0], frameCount * MemoryLayout<Float>.size)
            }
        }
        
        return monoBuffer
    }
    
    private func handleDiskFull() {
        // Stop recording gracefully
        audioFile = nil
        isRecording = false
        
        let fileURL = currentFileURL
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.wavRecorder(self, didEncounterError: .diskFull)
            
            // File is partial but valid
            if let url = fileURL {
                self.delegate?.wavRecorderDidStopRecording(self, fileURL: url, duration: self.recordingDuration)
            }
        }
    }
}

// MARK: - Disk Space Utilities

extension WavRecorder {
    
    /// Minimum free disk space required to start recording (100 MB)
    public static let minimumFreeDiskSpace: Int64 = 100 * 1024 * 1024
    
    /// Warning threshold for low disk space (500 MB)
    public static let lowDiskSpaceWarning: Int64 = 500 * 1024 * 1024
    
    /// Returns available disk space at the recordings location.
    public static func availableDiskSpace() -> Int64 {
        do {
            let recordingsDir = try recordingsDirectory(createIfNeeded: false)
            let values = try recordingsDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            // If we can't check, return a large value to not block recording
            return Int64.max
        }
    }
    
    /// Checks if there's enough disk space to record.
    /// - Returns: (canRecord, isLowSpace) tuple
    public static func checkDiskSpace() -> (canRecord: Bool, isLowSpace: Bool) {
        let available = availableDiskSpace()
        let canRecord = available >= minimumFreeDiskSpace
        let isLowSpace = available < lowDiskSpaceWarning
        return (canRecord, isLowSpace)
    }
    
    /// Estimated file size for a given duration.
    /// - Parameter duration: Recording duration in seconds
    /// - Returns: Estimated file size in bytes
    public static func estimatedFileSize(forDuration duration: TimeInterval) -> Int64 {
        // WAV file size = (Sample Rate × Bit Depth × Channels × Duration) / 8
        // At 48kHz, 16-bit, mono: ~5.5 MB per minute
        let bytesPerSecond: Double = 48000.0 * 2.0 * 1.0 // 48kHz, 16-bit (2 bytes), mono
        return Int64(bytesPerSecond * duration) + 44 // Add WAV header
    }
}
