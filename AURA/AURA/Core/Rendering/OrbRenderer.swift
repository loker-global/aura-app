import Foundation
import Metal
import MetalKit
import simd

/// Metal-based real-time orb renderer
/// Receives orb state from OrbPhysics
/// Renders single deformable sphere
final class OrbRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal Objects
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    
    // Buffers
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // MARK: - Geometry
    
    private var mesh: IcosphereMesh!
    private var indexCount: Int = 0
    
    // MARK: - Configuration (from SHADER-SPEC.md)
    
    // Colors (linear RGB)
    let orbColor = SIMD3<Float>(0.902, 0.906, 0.914)  // #E6E7E9 bone/off-white
    let backgroundColor = SIMD4<Float>(0.055, 0.059, 0.071, 1.0)  // #0E0F12 near-black
    
    // Camera
    let cameraPosition = SIMD3<Float>(0, 0, -3.0)
    let cameraTarget = SIMD3<Float>(0, 0, 0)
    let cameraUp = SIMD3<Float>(0, 1, 0)
    
    // Light
    let lightDirection = normalize(SIMD3<Float>(0.3, 0.5, -1.0))
    
    // MARK: - State
    
    private var currentOrbState = OrbState(radialExpansion: 0, rippleAmount: 0, surfaceTension: 10.0, time: 0)
    private var viewportSize = CGSize(width: 1, height: 1)
    
    // MARK: - Initialization
    
    init?(device: MTLDevice) {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue
        
        super.init()
        
        setupMesh()
        setupPipeline()
        setupDepthStencil()
        setupBuffers()
    }
    
    // MARK: - Setup
    
    private func setupMesh() {
        mesh = IcosphereMesh(subdivisionLevel: 5)
    }
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create default Metal library")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.sampleCount = 4  // MSAA
        
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        descriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func setupDepthStencil() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    private func setupBuffers() {
        // Vertex buffer
        vertexBuffer = device.makeBuffer(
            bytes: mesh.vertices,
            length: mesh.vertices.count * MemoryLayout<SIMD3<Float>>.stride,
            options: .storageModeShared
        )
        
        // Index buffer
        indexBuffer = device.makeBuffer(
            bytes: mesh.indices,
            length: mesh.indices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        indexCount = mesh.indices.count
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride,
            options: .storageModeShared
        )
    }
    
    // MARK: - Public Methods
    
    /// Update orb state from physics
    func updateOrbState(_ state: OrbState) {
        currentOrbState = state
    }
    
    /// Configure for MTKView
    func configure(view: MTKView) {
        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 4
        view.clearColor = MTLClearColor(
            red: Double(backgroundColor.x),
            green: Double(backgroundColor.y),
            blue: Double(backgroundColor.z),
            alpha: 1.0
        )
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Update uniforms
        updateUniforms()
        
        // Configure encoder
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
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
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Private Methods
    
    private func updateUniforms() {
        // View matrix
        let viewMatrix = lookAt(eye: cameraPosition, center: cameraTarget, up: cameraUp)
        
        // Projection matrix (orthographic)
        let aspect = Float(viewportSize.width / viewportSize.height)
        let orthoWidth: Float = 2.5
        let orthoHeight = orthoWidth / aspect
        let projectionMatrix = orthographic(
            left: -orthoWidth / 2,
            right: orthoWidth / 2,
            bottom: -orthoHeight / 2,
            top: orthoHeight / 2,
            near: 0.1,
            far: 10.0
        )
        
        // Model matrix (identity - orb at origin)
        let modelMatrix = matrix_identity_float4x4
        
        // MVP matrix
        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        // Create uniforms
        var uniforms = Uniforms(
            mvpMatrix: mvpMatrix,
            cameraPosition: cameraPosition,
            lightDirection: lightDirection,
            orbColor: orbColor,
            baseRadius: 1.0,
            radialExpansion: currentOrbState.radialExpansion,
            rippleAmplitude: currentOrbState.rippleAmount,
            time: currentOrbState.time
        )
        
        // Copy to buffer
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
    }
}

// MARK: - Uniform Structure

struct Uniforms {
    var mvpMatrix: float4x4
    var cameraPosition: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var orbColor: SIMD3<Float>
    var baseRadius: Float
    var radialExpansion: Float
    var rippleAmplitude: Float
    var time: Float
}

// MARK: - Matrix Helpers

private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    let translation = SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    
    return float4x4(columns: (
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        translation
    ))
}

private func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> float4x4 {
    let tx = -(right + left) / (right - left)
    let ty = -(top + bottom) / (top - bottom)
    let tz = -(far + near) / (far - near)
    
    return float4x4(columns: (
        SIMD4<Float>(2 / (right - left), 0, 0, 0),
        SIMD4<Float>(0, 2 / (top - bottom), 0, 0),
        SIMD4<Float>(0, 0, -2 / (far - near), 0),
        SIMD4<Float>(tx, ty, tz, 1)
    ))
}
