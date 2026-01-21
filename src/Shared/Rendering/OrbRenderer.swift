// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// OrbRenderer.swift — Metal-based real-time orb renderer

import Foundation
import MetalKit
import simd

// MARK: - Shader Uniforms (must match OrbShaders.metal)

/// Uniforms structure for Metal shaders.
/// Must be aligned to 16 bytes for Metal buffer binding.
public struct OrbUniforms {
    var modelViewProjectionMatrix: simd_float4x4
    var cameraPosition: simd_float3
    var _padding1: Float = 0
    var lightDirection: simd_float3
    var _padding2: Float = 0
    var orbColor: simd_float3
    var _padding3: Float = 0
    
    var baseRadius: Float
    var radialExpansion: Float
    var rippleAmplitude: Float
    var time: Float
    
    var debugWireframe: Bool
    var debugNormals: Bool
    var _padding4: simd_uint2 = .zero
}

// MARK: - OrbRendererDelegate

/// Delegate for receiving renderer events.
public protocol OrbRendererDelegate: AnyObject {
    /// Called when renderer needs updated physics state.
    func orbRendererNeedsPhysicsUpdate(_ renderer: OrbRenderer) -> OrbShaderState?
}

// MARK: - OrbRenderer

/// Metal-based real-time renderer for the AURA orb.
/// Per SHADER-SPEC.md: Forward rendering, Phong lighting, deformable sphere.
///
/// Features:
/// - 60fps minimum on Apple Silicon (120fps preferred)
/// - Physics-driven vertex displacement
/// - Simplex noise for micro-ripples
/// - Soft rim lighting
public final class OrbRenderer: NSObject {
    
    // MARK: - Configuration (from SHADER-SPEC.md)
    
    /// Background color: near-black (#0E0F12)
    public static let backgroundColor = MTLClearColor(
        red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0
    )
    
    /// Orb color: bone/off-white (#E6E7E9) in linear RGB
    public static let orbColor = SIMD3<Float>(0.902, 0.906, 0.914)
    
    /// Light direction: behind-right-above
    public static let lightDirection = simd_normalize(SIMD3<Float>(0.3, 0.5, -1.0))
    
    /// Camera position: 3 units back
    public static let cameraPosition = SIMD3<Float>(0, 0, -3.0)
    
    // MARK: - Properties
    
    /// Metal view for rendering
    public private(set) var mtkView: MTKView?
    
    /// Delegate for physics updates
    public weak var delegate: OrbRendererDelegate?
    
    /// Debug mode flags
    public var debugWireframe = false
    public var debugNormals = false
    
    /// Current time for shader animations
    private var time: Float = 0
    
    // MARK: - Metal Objects
    
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    // Geometry
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var vertexCount: Int = 0
    private var indexCount: Int = 0
    
    // Uniforms
    private var uniformBuffer: MTLBuffer!
    
    // Projection
    private var viewportSize: CGSize = .zero
    private var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
    private var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    /// Configures the renderer with a Metal view.
    /// - Parameter view: The MTKView to render to
    public func configure(with view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else {
            print("[OrbRenderer] Metal is not supported on this device")
            return
        }
        
        self.device = device
        self.mtkView = view
        
        view.device = device
        view.delegate = self
        view.clearColor = Self.backgroundColor
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 4 // 4× MSAA
        view.preferredFramesPerSecond = 60
        
        setupPipeline()
        setupGeometry()
        setupMatrices(viewportSize: view.drawableSize)
    }
    
    // MARK: - Setup
    
    private func setupPipeline() {
        guard let device = device else { return }
        
        // Command queue
        commandQueue = device.makeCommandQueue()
        
        // Load shaders from default library
        guard let library = device.makeDefaultLibrary() else {
            print("[OrbRenderer] Failed to load Metal library, using inline shaders")
            setupInlinePipeline()
            return
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        // Pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.sampleCount = 4
        
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("[OrbRenderer] Pipeline creation failed: \(error)")
            setupInlinePipeline()
            return
        }
        
        // Depth state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<OrbUniforms>.stride, options: .storageModeShared)
    }
    
    private func setupInlinePipeline() {
        // Fallback: Create pipeline with simple shaders if library fails
        guard let device = device else { return }
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexIn { float3 position [[attribute(0)]]; };
        struct VertexOut { float4 position [[position]]; float3 normal; };
        struct Uniforms { float4x4 mvp; float3 color; };
        
        vertex VertexOut vertex_simple(VertexIn in [[stage_in]], constant Uniforms& u [[buffer(1)]]) {
            VertexOut out;
            out.position = u.mvp * float4(in.position, 1.0);
            out.normal = normalize(in.position);
            return out;
        }
        
        fragment float4 fragment_simple(VertexOut in [[stage_in]], constant Uniforms& u [[buffer(0)]]) {
            float3 lightDir = normalize(float3(0.3, 0.5, -1.0));
            float diffuse = max(dot(in.normal, lightDir), 0.2);
            return float4(u.color * diffuse, 1.0);
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let vertexFunc = library.makeFunction(name: "vertex_simple")
            let fragmentFunc = library.makeFunction(name: "fragment_simple")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunc
            pipelineDescriptor.fragmentFunction = fragmentFunc
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineDescriptor.sampleCount = 4
            
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .less
            depthDescriptor.isDepthWriteEnabled = true
            depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
            
            uniformBuffer = device.makeBuffer(length: MemoryLayout<OrbUniforms>.stride, options: .storageModeShared)
        } catch {
            print("[OrbRenderer] Inline pipeline creation failed: \(error)")
        }
    }
    
    private func setupGeometry() {
        guard let device = device else { return }
        
        // Generate icosphere geometry
        let (vertices, indices) = generateIcosphere(subdivisions: 5)
        
        vertexCount = vertices.count
        indexCount = indices.count
        
        // Create vertex buffer
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
            options: .storageModeShared
        )
        
        // Create index buffer
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
    }
    
    private func setupMatrices(viewportSize: CGSize) {
        self.viewportSize = viewportSize
        
        let aspect = Float(viewportSize.width / viewportSize.height)
        
        // Orthographic projection (no perspective distortion)
        // Per SHADER-SPEC.md: Orb size constant regardless of distance
        let orthoWidth: Float = 2.5
        let orthoHeight: Float = 2.5 / aspect
        
        projectionMatrix = orthographicMatrix(
            left: -orthoWidth,
            right: orthoWidth,
            bottom: -orthoHeight,
            top: orthoHeight,
            near: 0.1,
            far: 10.0
        )
        
        // View matrix (camera looking at orb)
        viewMatrix = lookAtMatrix(
            eye: Self.cameraPosition,
            center: SIMD3<Float>(0, 0, 0),
            up: SIMD3<Float>(0, 1, 0)
        )
    }
    
    // MARK: - Icosphere Generation
    
    private func generateIcosphere(subdivisions: Int) -> ([SIMD3<Float>], [UInt32]) {
        let phi = Float((1.0 + sqrt(5.0)) / 2.0)
        
        // Base icosahedron vertices
        var vertices: [SIMD3<Float>] = [
            simd_normalize(SIMD3<Float>(-1, phi, 0)),
            simd_normalize(SIMD3<Float>(1, phi, 0)),
            simd_normalize(SIMD3<Float>(-1, -phi, 0)),
            simd_normalize(SIMD3<Float>(1, -phi, 0)),
            simd_normalize(SIMD3<Float>(0, -1, phi)),
            simd_normalize(SIMD3<Float>(0, 1, phi)),
            simd_normalize(SIMD3<Float>(0, -1, -phi)),
            simd_normalize(SIMD3<Float>(0, 1, -phi)),
            simd_normalize(SIMD3<Float>(phi, 0, -1)),
            simd_normalize(SIMD3<Float>(phi, 0, 1)),
            simd_normalize(SIMD3<Float>(-phi, 0, -1)),
            simd_normalize(SIMD3<Float>(-phi, 0, 1))
        ]
        
        // Base faces
        var faces: [(UInt32, UInt32, UInt32)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]
        
        // Subdivide
        for _ in 0..<subdivisions {
            var newFaces: [(UInt32, UInt32, UInt32)] = []
            var midpointCache: [String: UInt32] = [:]
            
            for (i0, i1, i2) in faces {
                let a = getMidpoint(i0, i1, vertices: &vertices, cache: &midpointCache)
                let b = getMidpoint(i1, i2, vertices: &vertices, cache: &midpointCache)
                let c = getMidpoint(i2, i0, vertices: &vertices, cache: &midpointCache)
                
                newFaces.append((i0, a, c))
                newFaces.append((i1, b, a))
                newFaces.append((i2, c, b))
                newFaces.append((a, b, c))
            }
            
            faces = newFaces
        }
        
        // Convert faces to index array
        var indices: [UInt32] = []
        for (i0, i1, i2) in faces {
            indices.append(i0)
            indices.append(i1)
            indices.append(i2)
        }
        
        return (vertices, indices)
    }
    
    private func getMidpoint(
        _ i0: UInt32,
        _ i1: UInt32,
        vertices: inout [SIMD3<Float>],
        cache: inout [String: UInt32]
    ) -> UInt32 {
        let key = i0 < i1 ? "\(i0)-\(i1)" : "\(i1)-\(i0)"
        
        if let index = cache[key] {
            return index
        }
        
        let midpoint = simd_normalize((vertices[Int(i0)] + vertices[Int(i1)]) / 2.0)
        let index = UInt32(vertices.count)
        vertices.append(midpoint)
        cache[key] = index
        
        return index
    }
    
    // MARK: - Matrix Helpers
    
    private func orthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let w = right - left
        let h = top - bottom
        let d = far - near
        
        return simd_float4x4(columns: (
            SIMD4<Float>(2.0 / w, 0, 0, 0),
            SIMD4<Float>(0, 2.0 / h, 0, 0),
            SIMD4<Float>(0, 0, -2.0 / d, 0),
            SIMD4<Float>(-(right + left) / w, -(top + bottom) / h, -(far + near) / d, 1)
        ))
    }
    
    private func lookAtMatrix(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(center - eye)
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)
        
        return simd_float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
        ))
    }
}

// MARK: - MTKViewDelegate

extension OrbRenderer: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setupMatrices(viewportSize: size)
    }
    
    public func draw(in view: MTKView) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Update time
        time += 1.0 / 60.0
        
        // Get physics state from delegate
        let physicsState = delegate?.orbRendererNeedsPhysicsUpdate(self) ?? OrbShaderState(
            baseRadius: 1.0,
            radialExpansion: 0,
            rippleAmplitude: 0,
            time: time
        )
        
        // Update uniforms
        var uniforms = OrbUniforms(
            modelViewProjectionMatrix: projectionMatrix * viewMatrix,
            cameraPosition: Self.cameraPosition,
            lightDirection: Self.lightDirection,
            orbColor: Self.orbColor,
            baseRadius: physicsState.baseRadius,
            radialExpansion: physicsState.radialExpansion,
            rippleAmplitude: physicsState.rippleAmplitude,
            time: physicsState.time,
            debugWireframe: debugWireframe,
            debugNormals: debugNormals
        )
        
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<OrbUniforms>.stride)
        
        // Configure encoder
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        // Set buffers
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
}

// MARK: - Headless Rendering (for Export)

extension OrbRenderer {
    
    /// Creates a texture for headless rendering (export).
    /// - Parameters:
    ///   - width: Texture width
    ///   - height: Texture height
    /// - Returns: Render target texture
    public func createRenderTexture(width: Int, height: Int) -> MTLTexture? {
        guard let device = device else { return nil }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    /// Renders a single frame to a texture (for export).
    /// - Parameters:
    ///   - texture: Target texture
    ///   - physicsState: Physics state for this frame
    public func renderToTexture(_ texture: MTLTexture, physicsState: OrbShaderState) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Create depth texture
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .private
        
        guard let depthTexture = device.makeTexture(descriptor: depthDescriptor) else { return }
        
        // Render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = Self.backgroundColor
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        // Update matrices for texture size
        let aspect = Float(texture.width) / Float(texture.height)
        let orthoWidth: Float = 2.5
        let orthoHeight: Float = 2.5 / aspect
        
        let projMatrix = orthographicMatrix(
            left: -orthoWidth,
            right: orthoWidth,
            bottom: -orthoHeight,
            top: orthoHeight,
            near: 0.1,
            far: 10.0
        )
        
        var uniforms = OrbUniforms(
            modelViewProjectionMatrix: projMatrix * viewMatrix,
            cameraPosition: Self.cameraPosition,
            lightDirection: Self.lightDirection,
            orbColor: Self.orbColor,
            baseRadius: physicsState.baseRadius,
            radialExpansion: physicsState.radialExpansion,
            rippleAmplitude: physicsState.rippleAmplitude,
            time: physicsState.time,
            debugWireframe: false,
            debugNormals: false
        )
        
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<OrbUniforms>.stride)
        
        // Configure and draw
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
