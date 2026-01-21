// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// OrbExporter.swift — Offline video renderer with audio mux

import AVFoundation
import MetalKit

// MARK: - OrbExporterDelegate

/// Delegate for receiving export events.
public protocol OrbExporterDelegate: AnyObject {
    /// Called when export progress updates.
    func orbExporter(_ exporter: OrbExporter, didUpdateProgress progress: Float)
    
    /// Called when export completes successfully.
    func orbExporterDidComplete(_ exporter: OrbExporter, outputURL: URL)
    
    /// Called when export fails.
    func orbExporter(_ exporter: OrbExporter, didFailWithError error: OrbExporterError)
    
    /// Called when export is canceled.
    func orbExporterDidCancel(_ exporter: OrbExporter)
}

// MARK: - OrbExporterError

/// Errors that can occur during video export.
public enum OrbExporterError: Error, LocalizedError {
    case audioLoadFailed(URL)
    case writerCreationFailed
    case encodingFailed
    case diskFull
    case canceled
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .audioLoadFailed(let url):
            return "Could not load audio file: \(url.lastPathComponent)"
        case .writerCreationFailed:
            return "Failed to create video writer."
        case .encodingFailed:
            return "Video encoding failed."
        case .diskFull:
            return "Export canceled. Not enough disk space."
        case .canceled:
            return "Export canceled."
        case .timeout:
            return "Export timed out. Please try again."
        }
    }
}

// MARK: - Export Configuration (from EXPORT-SPEC.md)

/// Video export configuration.
public struct ExportConfiguration {
    /// Video width (default: 1920 for 1080p)
    public var width: Int = 1920
    
    /// Video height (default: 1080 for 1080p)
    public var height: Int = 1080
    
    /// Frame rate (default: 60 fps)
    public var frameRate: Int = 60
    
    /// Video bit rate (default: 8 Mbps)
    public var videoBitRate: Int = 8_000_000
    
    /// Audio bit rate (default: 128 kbps)
    public var audioBitRate: Int = 128_000
    
    /// Video codec (H.264 for compatibility)
    public var videoCodec: AVVideoCodecType = .h264
    
    /// Default 1080p60 configuration
    public static let standard = ExportConfiguration()
    
    /// 720p30 for smaller file size
    public static let compact = ExportConfiguration(
        width: 1280,
        height: 720,
        frameRate: 30,
        videoBitRate: 5_000_000
    )
    
    public init(
        width: Int = 1920,
        height: Int = 1080,
        frameRate: Int = 60,
        videoBitRate: Int = 8_000_000,
        audioBitRate: Int = 128_000,
        videoCodec: AVVideoCodecType = .h264
    ) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.videoBitRate = videoBitRate
        self.audioBitRate = audioBitRate
        self.videoCodec = videoCodec
    }
}

// MARK: - OrbExporter

/// Exports orb animation as MP4 video with audio.
/// Per EXPORT-SPEC.md: H.264, 1080p60, 8 Mbps, AAC audio.
///
/// Workflow:
/// 1. Load audio file
/// 2. Extract audio features offline
/// 3. Run physics simulation (deterministic replay)
/// 4. Render frames headlessly
/// 5. Mux video + audio to MP4
public final class OrbExporter {
    
    // MARK: - Properties
    
    /// Export configuration
    public let configuration: ExportConfiguration
    
    /// Delegate for export events
    public weak var delegate: OrbExporterDelegate?
    
    /// Whether export is in progress
    public private(set) var isExporting = false
    
    /// Whether export was canceled
    private var isCanceled = false
    
    // MARK: - Private Properties
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private let renderer: OrbRenderer
    private let physics: OrbPhysics
    private let featureExtractor: AudioFeatureExtractor
    
    private var exportQueue = DispatchQueue(label: "com.aura.exporter", qos: .userInitiated)
    private var renderTexture: MTLTexture?
    
    // MARK: - Initialization
    
    public init(configuration: ExportConfiguration = .standard) {
        self.configuration = configuration
        self.renderer = OrbRenderer()
        self.physics = OrbPhysics()
        self.featureExtractor = AudioFeatureExtractor()
        
        // Setup headless Metal renderer
        setupHeadlessRenderer()
    }
    
    // MARK: - Public Methods
    
    /// Starts exporting video from an audio file.
    /// - Parameters:
    ///   - audioURL: Source audio file URL
    ///   - outputURL: Destination video file URL
    public func startExport(audioURL: URL, outputURL: URL) {
        guard !isExporting else { return }
        
        isExporting = true
        isCanceled = false
        
        exportQueue.async { [weak self] in
            self?.performExport(audioURL: audioURL, outputURL: outputURL)
        }
    }
    
    /// Cancels the current export.
    public func cancelExport() {
        guard isExporting else { return }
        isCanceled = true
    }
    
    // MARK: - Private Methods
    
    private func setupHeadlessRenderer() {
        // Create headless Metal device and configure renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[OrbExporter] Metal not available for export")
            return
        }
        
        // Create a headless MTKView for renderer setup
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height), device: device)
        renderer.configure(with: view)
        
        // Create render texture for headless rendering
        renderTexture = renderer.createRenderTexture(width: configuration.width, height: configuration.height)
    }
    
    private func performExport(audioURL: URL, outputURL: URL) {
        // 1. Load audio file
        guard let audioFile = try? AVAudioFile(forReading: audioURL) else {
            reportError(.audioLoadFailed(audioURL))
            return
        }
        
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        let totalFrames = Int(duration * Double(configuration.frameRate))
        
        // 2. Setup asset writer
        guard setupAssetWriter(outputURL: outputURL, duration: duration) else {
            reportError(.writerCreationFailed)
            return
        }
        
        // 3. Reset physics and feature extractor
        physics.reset()
        featureExtractor.reset()
        
        // 4. Process frames
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)
        
        var frameIndex = 0
        let frameDuration = 1.0 / Double(configuration.frameRate)
        
        // Process audio and render frames
        while frameIndex < totalFrames && !isCanceled {
            // Calculate current time
            let currentTime = Double(frameIndex) * frameDuration
            
            // Extract audio features at current time
            let features = extractFeaturesAt(time: currentTime, from: audioFile)
            
            // Apply forces to physics
            physics.applyForces(
                radialForce: features.rms,
                tension: features.surfaceTension(),
                rippleAmplitude: features.zeroCrossingRate,
                impulse: features.onsetDetected ? features.onsetMagnitude : 0,
                isSilent: features.isSilent
            )
            
            // Update physics
            physics.update()
            
            // Render frame
            if let pixelBuffer = renderFrame(physicsState: physics.shaderState) {
                appendVideoFrame(pixelBuffer: pixelBuffer, frameIndex: frameIndex)
            }
            
            // Update progress
            let progress = Float(frameIndex) / Float(totalFrames)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.orbExporter(self, didUpdateProgress: progress)
            }
            
            frameIndex += 1
        }
        
        // 5. Handle cancellation
        if isCanceled {
            assetWriter?.cancelWriting()
            cleanup(outputURL: outputURL)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.orbExporterDidCancel(self)
            }
            return
        }
        
        // 6. Add audio track
        addAudioTrack(from: audioURL)
        
        // 7. Finalize
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            self.isExporting = false
            
            if self.assetWriter?.status == .completed {
                DispatchQueue.main.async {
                    self.delegate?.orbExporterDidComplete(self, outputURL: outputURL)
                }
            } else {
                self.cleanup(outputURL: outputURL)
                DispatchQueue.main.async {
                    self.delegate?.orbExporter(self, didFailWithError: .encodingFailed)
                }
            }
        }
    }
    
    private func setupAssetWriter(outputURL: URL, duration: Double) -> Bool {
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create asset writer
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return false
        }
        
        // Video settings (per EXPORT-SPEC.md)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.videoCodec,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2 // Keyframe every 2 seconds
            ]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        // Pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: configuration.width,
            kCVPixelBufferHeightKey as String: configuration.height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // Audio settings (AAC, 128 kbps mono)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: configuration.audioBitRate
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = false
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }
        
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }
        
        self.assetWriter = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = adaptor
        
        return true
    }
    
    private func extractFeaturesAt(time: TimeInterval, from audioFile: AVAudioFile) -> AudioFeatures {
        let sampleRate = audioFile.fileFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)
        
        // Read buffer at position
        let bufferSize: AVAudioFrameCount = 2048
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: bufferSize) else {
            return .silent
        }
        
        let originalPosition = audioFile.framePosition
        audioFile.framePosition = max(0, min(framePosition, audioFile.length - AVAudioFramePosition(bufferSize)))
        
        do {
            try audioFile.read(into: buffer)
            audioFile.framePosition = originalPosition
            
            guard let channelData = buffer.floatChannelData else {
                return .silent
            }
            
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
            
            return featureExtractor.extractFeatures(
                from: samples,
                sampleRate: Float(sampleRate),
                currentTime: time
            )
        } catch {
            audioFile.framePosition = originalPosition
            return .silent
        }
    }
    
    private func renderFrame(physicsState: OrbShaderState) -> CVPixelBuffer? {
        guard let texture = renderTexture else { return nil }
        
        // Render orb to texture
        renderer.renderToTexture(texture, physicsState: physicsState)
        
        // Create pixel buffer from texture
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            configuration.width,
            configuration.height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        // Copy texture data to pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let region = MTLRegionMake2D(0, 0, configuration.width, configuration.height)
        
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        return buffer
    }
    
    private func appendVideoFrame(pixelBuffer: CVPixelBuffer, frameIndex: Int) {
        guard let adaptor = pixelBufferAdaptor,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        let frameTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(configuration.frameRate))
        adaptor.append(pixelBuffer, withPresentationTime: frameTime)
    }
    
    private func addAudioTrack(from audioURL: URL) {
        guard let audioInput = audioInput else { return }
        
        // Read audio file and write to audio input
        let asset = AVAsset(url: audioURL)
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else { return }
        
        do {
            let reader = try AVAssetReader(asset: asset)
            let readerOutput = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false
                ]
            )
            
            if reader.canAdd(readerOutput) {
                reader.add(readerOutput)
            }
            
            reader.startReading()
            
            while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                if isCanceled { break }
                
                while !audioInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                
                audioInput.append(sampleBuffer)
            }
            
            reader.cancelReading()
            
        } catch {
            print("[OrbExporter] Failed to add audio track: \(error)")
        }
    }
    
    private func cleanup(outputURL: URL) {
        isExporting = false
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        
        // Delete partial file
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    private func reportError(_ error: OrbExporterError) {
        isExporting = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.orbExporter(self, didFailWithError: error)
        }
    }
}

// MARK: - Export Utilities

extension OrbExporter {
    
    /// Estimates the output file size for a given duration.
    /// - Parameter duration: Audio duration in seconds
    /// - Returns: Estimated file size in bytes
    public func estimatedFileSize(forDuration duration: TimeInterval) -> Int64 {
        // Video: bitrate × duration / 8
        let videoBits = Double(configuration.videoBitRate) * duration
        let videoBytes = Int64(videoBits / 8.0)
        
        // Audio: bitrate × duration / 8
        let audioBits = Double(configuration.audioBitRate) * duration
        let audioBytes = Int64(audioBits / 8.0)
        
        // Add overhead for container
        let overhead: Int64 = 1024 * 100 // ~100 KB overhead
        
        return videoBytes + audioBytes + overhead
    }
    
    /// Generates default output filename based on source audio.
    /// - Parameter audioURL: Source audio file URL
    /// - Returns: Suggested output URL with .mp4 extension
    public static func suggestOutputURL(for audioURL: URL) -> URL {
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let directory = audioURL.deletingLastPathComponent()
        return directory.appendingPathComponent("\(baseName).mp4")
    }
}
