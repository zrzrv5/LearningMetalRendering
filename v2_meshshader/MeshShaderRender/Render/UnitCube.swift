//
//  UnitCube.swift
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/23/24.
//

import Metal

struct UnitCubeVertices {
    static let vertices: [SIMD3<Float>] = [
        SIMD3<Float>(-1.0, -1.0, -1.0),
        SIMD3<Float>( 1.0, -1.0, -1.0),
        SIMD3<Float>(-1.0,  1.0, -1.0),
        SIMD3<Float>( 1.0,  1.0, -1.0),
        SIMD3<Float>(-1.0, -1.0,  1.0),
        SIMD3<Float>( 1.0, -1.0,  1.0),
        SIMD3<Float>(-1.0,  1.0,  1.0),
        SIMD3<Float>( 1.0,  1.0,  1.0),
        SIMD3<Float>(-1.0, -1.0, -1.0),
        SIMD3<Float>( 1.0, -1.0, -1.0),
        SIMD3<Float>(-1.0,  1.0, -1.0),
        SIMD3<Float>( 1.0,  1.0, -1.0),
        SIMD3<Float>(-1.0, -1.0,  1.0),
        SIMD3<Float>( 1.0, -1.0,  1.0)
    ]
}
