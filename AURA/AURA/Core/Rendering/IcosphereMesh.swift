import Foundation
import simd

/// Generates icosphere mesh geometry
/// Pre-computed at init time
final class IcosphereMesh {
    
    // MARK: - Properties
    
    private(set) var vertices: [SIMD3<Float>] = []
    private(set) var indices: [UInt32] = []
    
    // MARK: - Initialization
    
    init(subdivisionLevel: Int = 5) {
        generateIcosphere(subdivisionLevel: subdivisionLevel)
    }
    
    // MARK: - Generation
    
    private func generateIcosphere(subdivisionLevel: Int) {
        // Golden ratio
        let phi: Float = (1.0 + sqrt(5.0)) / 2.0
        
        // Initial icosahedron vertices (normalized)
        let initialVertices: [SIMD3<Float>] = [
            normalize(SIMD3<Float>(-1, phi, 0)),
            normalize(SIMD3<Float>(1, phi, 0)),
            normalize(SIMD3<Float>(-1, -phi, 0)),
            normalize(SIMD3<Float>(1, -phi, 0)),
            normalize(SIMD3<Float>(0, -1, phi)),
            normalize(SIMD3<Float>(0, 1, phi)),
            normalize(SIMD3<Float>(0, -1, -phi)),
            normalize(SIMD3<Float>(0, 1, -phi)),
            normalize(SIMD3<Float>(phi, 0, -1)),
            normalize(SIMD3<Float>(phi, 0, 1)),
            normalize(SIMD3<Float>(-phi, 0, -1)),
            normalize(SIMD3<Float>(-phi, 0, 1))
        ]
        
        // Initial icosahedron faces (20 triangles)
        let initialFaces: [(Int, Int, Int)] = [
            // 5 faces around point 0
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            // 5 adjacent faces
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            // 5 faces around point 3
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            // 5 adjacent faces
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]
        
        // Build vertex and index lists
        var currentVertices = initialVertices
        var currentFaces = initialFaces
        
        // Subdivide
        for _ in 0..<subdivisionLevel {
            (currentVertices, currentFaces) = subdivide(vertices: currentVertices, faces: currentFaces)
        }
        
        // Store results
        vertices = currentVertices
        indices = currentFaces.flatMap { [UInt32($0.0), UInt32($0.1), UInt32($0.2)] }
    }
    
    private func subdivide(vertices: [SIMD3<Float>], faces: [(Int, Int, Int)]) -> ([SIMD3<Float>], [(Int, Int, Int)]) {
        var newVertices = vertices
        var newFaces: [(Int, Int, Int)] = []
        var midpointCache: [String: Int] = [:]
        
        func getMidpoint(_ i1: Int, _ i2: Int) -> Int {
            // Create unique key (order-independent)
            let key = i1 < i2 ? "\(i1)-\(i2)" : "\(i2)-\(i1)"
            
            if let cachedIndex = midpointCache[key] {
                return cachedIndex
            }
            
            // Calculate midpoint and normalize to unit sphere
            let midpoint = normalize((vertices[i1] + vertices[i2]) * 0.5)
            let newIndex = newVertices.count
            newVertices.append(midpoint)
            midpointCache[key] = newIndex
            
            return newIndex
        }
        
        for (i0, i1, i2) in faces {
            // Get midpoints
            let a = getMidpoint(i0, i1)
            let b = getMidpoint(i1, i2)
            let c = getMidpoint(i2, i0)
            
            // Create 4 new triangles
            newFaces.append((i0, a, c))
            newFaces.append((i1, b, a))
            newFaces.append((i2, c, b))
            newFaces.append((a, b, c))
        }
        
        return (newVertices, newFaces)
    }
}
