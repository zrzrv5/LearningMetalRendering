//
//  World.swift
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/22/24.
//

import MetalKit

class Word{
    var cameraAngle: Float = 0.0
    
    var cameraPosition = float4x4(translationBy: SIMD3<Float>(0,0,20))
    
        
    
    var Spheres = [Sphere]()
    
    let SPHERE_RADIUS :Float = 1.0
    let SPHERE_PADDING :Float = 1.0
    
    let Nx: Int = 60
    
    var sphereMesh: MTKMesh!
    
    init(device:MTLDevice,LoD:uint=14,vertexDescriptor:MDLVertexDescriptor) {
        let meshAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: SIMD3<Float>(1,1,1),
            segments: uint2(LoD,LoD),
            inwardNormals: false,
            geometryType: .triangles,
            allocator: meshAllocator)
        mdlMesh.vertexDescriptor = vertexDescriptor
        
        
        guard let sphereMesh = try? MTKMesh(mesh: mdlMesh, device: device) else {
            print("Failed to create sphere mesh")
            fatalError()
        }
        
        self.sphereMesh = sphereMesh
        
        let gridSideLength = (SPHERE_RADIUS * 2 * Float(Nx)) + (SPHERE_PADDING * Float(Nx - 1))
        
        for j in 0..<Nx{
            for i in 0..<Nx{
                for k in 0..<Nx{
                    let position = SIMD3<Float>(
                        SPHERE_RADIUS + Float(i) * (2 * SPHERE_RADIUS + SPHERE_PADDING) - (Float(gridSideLength) / 2),
                        SPHERE_RADIUS + Float(j) * (2 * SPHERE_RADIUS + SPHERE_PADDING) - (Float(gridSideLength) / 2),
                        SPHERE_RADIUS + Float(k) * (2 * SPHERE_RADIUS + SPHERE_PADDING) - (Float(gridSideLength) / 2)
                    )
                    
                    let sphere = Sphere(nil, float4x4(translationBy: position))
                    sphere.material.color = SIMD4<Float>(hue: Float(drand48()), saturation: 1.0, brightness: 1.0)
                    self.Spheres.append(sphere)
//                    print("\(i),\(j),\(k): ")
//                    print(sphere.transform)
                }

                
            }
        }
    
        print("\(Nx)X\(Nx)X\(Nx) | Total \(Spheres.count) Shperes")
        
        
    }
    
    
}

class Sphere{
    var mesh: MTKMesh?
    var material =  Material()
    var transform: float4x4
    
    init(_ mesh: MTKMesh?, _ transform: float4x4?) {
        self.mesh = mesh
        if let transform = transform{
            self.transform = transform
        }else{
            self.transform = matrix_identity_float4x4
        }
        
    }
}

class Material{
    var color = float4(1, 1, 1, 1)
    var highlighted: Bool = false
}

struct InstanceData {
    var modelMatrix: float4x4
    var normalMatrix: float4x4
    var color: float4
}
