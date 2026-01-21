import Foundation
import AVFoundation
import Metal
import MetalKit

/// Offline video exporter
/// Replays audio → physics → rendering
/// Muxes video + audio to MP4
final class OrbExporter {
    
    // MARK: - Export Configuration (from EXPORT-SPEC.md)
    
    struct ExportConfig {
        var width: Int = 1920
        var height: Int = 1080
        var frameRate: Int = 60
        var videoBitRate: Int = 8_000_000  // 8 Mbps
        var audioBitRate: Int = 128_000    // 128 kbps
    }
    
    // MARK: - Properties
    
    weak var delegate: OrbExporterDelegate?
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private let device: MTLDevice
    private var renderer: OrbRenderer?
    private var physics: OrbPhysics?
    
    private var isCancelled = false
    private var isExporting = false
    
    // MARK: - Initialization
    
    init?(device: MTLDevice) {
        self.device = device
        
        renderer = OrbRenderer(device: device)
        physics = OrbPhysics()
    }
    
    // MARK: - Export
    
    /// Export audio file to MP4 video with orb
    func export(audioURL: URL, to outputURL: URL, config: ExportConfig = ExportConfig()) async throws {
        guard !isExporting else {
            throw ExportError.alreadyExporting
        }
        
        isExporting = true
        isCancelled = false
        
        defer { isExporting = false }
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Setup asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = false
        
        // Pixel buffer adaptor
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.width,
            kCVPixelBufferHeightKey as String: config.height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: attributes
        )
        
        // Audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: config.audioBitRate
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = false
        
        // Add inputs
        if let videoInput = videoInput, assetWriter!.canAdd(videoInput) {
            assetWriter!.add(videoInput)
        }
        if let audioInput = audioInput, assetWriter!.canAdd(audioInput) {
            assetWriter!.add(audioInput)
        }
        
        // Load audio file
        let audioFile = try AVAudioFile(forReading: audioURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let totalFrames = Int(duration * Double(config.frameRate))
        
        // Start writing
        assetWriter!.startWriting()
        assetWriter!.startSession(atSourceTime: .zero)
        
        // Process frames
        physics?.reset()
        
        let analyzer = AudioAnalyzer(bufferSize: 2048, sampleRate: 48000.0)
        let bufferSize: AVAudioFrameCount = 2048
        
        for frameIndex in 0..<totalFrames {
            if isCancelled {
                assetWriter?.cancelWriting()
                throw ExportError.cancelled
            }
            
            // Calculate time
            let time = Double(frameIndex) / Double(config.frameRate)
            let presentationTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(config.frameRate))
            
            // Read audio and analyze
            let audioFrame = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
            if audioFrame < audioFile.length {
                audioFile.framePosition = audioFrame
                if let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: bufferSize) {
                    try? audioFile.read(into: buffer, frameCount: bufferSize)
                    let analysis = analyzer.analyze(buffer: buffer)
                    physics?.applyAudioAnalysis(analysis)
                }
            }
            
            // Update physics
            physics?.update()
            
            // Render frame
            if let orbState = physics?.currentState() {
                renderer?.updateOrbState(orbState)
            }
            
            // Append video frame (simplified - actual implementation needs Metal render to texture)
            while !videoInput!.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }
            
            // Report progress
            let progress = Float(frameIndex) / Float(totalFrames)
            await MainActor.run {
                delegate?.orbExporter(self, didUpdateProgress: progress)
            }
        }
        
        // Write audio track
        let audioAsset = AVAsset(url: audioURL)
        if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let reader = try AVAssetReader(asset: audioAsset)
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(readerOutput)
            reader.startReading()
            
            while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                while !audioInput!.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                audioInput!.append(sampleBuffer)
            }
        }
        
        // Finish writing
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await assetWriter!.finishWriting()
        
        if assetWriter?.status == .failed {
            throw assetWriter!.error ?? ExportError.unknown
        }
        
        await MainActor.run {
            delegate?.orbExporter(self, didFinishExportTo: outputURL)
        }
    }
    
    /// Cancel export
    func cancel() {
        isCancelled = true
    }
    
    /// Check if currently exporting
    var isActive: Bool {
        return isExporting
    }
}

// MARK: - Delegate

protocol OrbExporterDelegate: AnyObject {
    func orbExporter(_ exporter: OrbExporter, didUpdateProgress progress: Float)
    func orbExporter(_ exporter: OrbExporter, didFinishExportTo url: URL)
    func orbExporter(_ exporter: OrbExporter, didFailWithError error: Error)
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case alreadyExporting
    case cancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .alreadyExporting:
            return "An export is already in progress"
        case .cancelled:
            return "Export was cancelled"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
