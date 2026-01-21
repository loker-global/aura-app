import Foundation
import AVFoundation

/// Deterministic WAV file writer
/// Receives PCM buffers from AudioCaptureEngine
/// Handles partial file safety (write header on close)
final class WavRecorder {
    
    // MARK: - Configuration (from FILE-MANAGEMENT.md)
    
    private let sampleRate: Double = 48000.0
    private let bitsPerSample: UInt16 = 16
    private let numChannels: UInt16 = 1
    
    // MARK: - State
    
    private var fileHandle: FileHandle?
    private var currentURL: URL?
    private var dataSize: UInt32 = 0
    private var isRecording = false
    
    private let queue = DispatchQueue(label: "gold.ok.aura.wavrecorder", qos: .userInitiated)
    
    // MARK: - Recording Control
    
    /// Start recording to a new WAV file
    func startRecording(to url: URL) throws {
        try queue.sync {
            guard !isRecording else { return }
            
            // Create file
            FileManager.default.createFile(atPath: url.path, contents: nil)
            fileHandle = try FileHandle(forWritingTo: url)
            currentURL = url
            dataSize = 0
            
            // Write placeholder header (will be updated on close)
            let header = createWavHeader(dataSize: 0)
            fileHandle?.write(header)
            
            isRecording = true
        }
    }
    
    /// Write audio buffer to file
    func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            guard let floatData = buffer.floatChannelData?[0] else { return }
            
            let frameCount = Int(buffer.frameLength)
            let samples = UnsafeBufferPointer(start: floatData, count: frameCount)
            
            // Convert Float32 to Int16
            var int16Samples = [Int16]()
            int16Samples.reserveCapacity(frameCount)
            
            for sample in samples {
                let clampedSample = max(-1.0, min(1.0, sample))
                let int16Sample = Int16(clampedSample * Float(Int16.max))
                int16Samples.append(int16Sample)
            }
            
            // Write to file
            let data = Data(bytes: int16Samples, count: frameCount * 2)
            self.fileHandle?.write(data)
            self.dataSize += UInt32(data.count)
        }
    }
    
    /// Stop recording and finalize file
    func stopRecording() -> URL? {
        return queue.sync {
            guard isRecording else { return nil }
            
            // Update header with final size
            fileHandle?.seek(toFileOffset: 0)
            let header = createWavHeader(dataSize: dataSize)
            fileHandle?.write(header)
            
            // Close file
            try? fileHandle?.close()
            fileHandle = nil
            isRecording = false
            
            let url = currentURL
            currentURL = nil
            
            return url
        }
    }
    
    /// Check if currently recording
    var isActive: Bool {
        return isRecording
    }
    
    // MARK: - WAV Header
    
    private func createWavHeader(dataSize: UInt32) -> Data {
        var header = Data()
        
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let chunkSize = 36 + dataSize
        
        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt subchunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // AudioFormat (PCM)
        header.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data subchunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        
        return header
    }
    
    // MARK: - File Management
    
    /// Generate default recording URL
    static func defaultRecordingURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "AURA-\(timestamp).wav"
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let auraFolder = documentsURL.appendingPathComponent("AURA Recordings", isDirectory: true)
        
        // Create folder if needed
        try? FileManager.default.createDirectory(at: auraFolder, withIntermediateDirectories: true)
        
        return auraFolder.appendingPathComponent(filename)
    }
}
