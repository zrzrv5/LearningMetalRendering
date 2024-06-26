//
//  Render.swift
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/22/24.
//

import MetalKit

class Render: NSObject, MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("drawable Size will change to \(size)")
    }
    func draw(in view: MTKView) {
        //
        frameSemaphore.wait()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot make command buffer")
            return
        }
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            print("cannot get current render pass descriptor")
            return
        }
        
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        // update cameraAngle
        
//        if self.world.cameraAngle > 360.0 {
//            self.world.cameraAngle = 0.05
//        }else{
            self.world.cameraAngle += 0.01
//        }
        // get view's width and height
        let w = view.frame.width
        let h = view.frame.height
        
        let aspectRatio = w / h
        var projectionMatrix = float4x4(
            perspectiveProjectionRHFovY: radians_from_degrees(65),
            aspectRatio: Float(aspectRatio),
            nearZ: 0.1,
            farZ: 100.0)
        
        var eye = SIMD3<Float>(15 * sin(world.cameraAngle), 0, 15 * cos(world.cameraAngle))
        let center = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        
        var viewMatrix = float4x4(lookAt: eye, center: center, up: up)
        
        
        var viewProjectionMatrix = projectionMatrix * viewMatrix
        var viewsize = float2(Float(w),Float(h))
        
//        drawSpheresUsingInstancing(viewProjMat: &viewProjectionMatrix, in: renderCommandEncoder)
        
        // need to fix RaySphere ,
//        drawSpheresUsingRayIntersect(viewportSize: &viewsize, viewMat: &viewMatrix, projMat: &projectionMatrix, cameraPos: &eye, in: renderCommandEncoder)
        
        drawSphereUsingMeshShader(viewProjMat: &viewProjectionMatrix, in: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        //
        if let drawable = view.currentDrawable{
            commandBuffer.present(drawable)
        }
        
        commandBuffer.addCompletedHandler { _ in
            self.frameSemaphore.signal()
        }
        
        commandBuffer.commit()
        
    }
    

    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let instancingRenderPipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    
    let raySphereRenderPipelineState: MTLRenderPipelineState
    
    let meshShaderRenderPipelineState: MTLRenderPipelineState
    
//
    var parent: RenderView
    var world: Word
    
    let frameSemaphore = DispatchSemaphore(value: 3)
    var instanceBuffer : MTLBuffer!
    

    
    var spherePositionsBuffer: MTLBuffer!
    var sphereRadiiBuffer: MTLBuffer!
    var sphereColorsBuffer: MTLBuffer!
    
    
    
    
    init(_ parent:RenderView){
        self.parent = parent
        
        self.device = MTLCreateSystemDefaultDevice()!
        
        self.world = Word(device: self.device,vertexDescriptor: vertexDescriptor)
        
        self.commandQueue = device.makeCommandQueue()!
        self.depthStencilState = Render.makeDepthStencilState(device: self.device)
        
        

        guard let library = device.makeDefaultLibrary() else {
                fatalError("failed to craete default lib")
        }

        
        
        // old instancingRender
        do{
            self.instancingRenderPipelineState = try Render.makeRenderPipelineState(devive: self.device, library: library, vertexDescriptor: self.vertexDescriptor)
        }catch{
            fatalError("cannot make Instancing render pipeline state")
        }
        // raySphereRender
        do{
            self.raySphereRenderPipelineState = try Render.makeRaySphereRenderPipelineState(device: self.device, library: library)
        }catch{
            fatalError("cannnot make RS render pipeline state")
        }
        // mesh shader
        do{
            self.meshShaderRenderPipelineState = try Render.makeMeshShaderRenderPipelineState(device: self.device, library: library)
        }catch{
            fatalError("cannnot make Mesh Shader Render pipeline state")
        }
        
        
        
        var instanceData = [InstanceData]()
        var spherePositions: [SIMD3<Float>] = []
        var sphereRadii: [Float] = []
        var sphereColors: [SIMD4<Float>] = []
        
        for sphere in self.world.Spheres{
            instanceData.append(
                InstanceData(modelMatrix: sphere.transform, normalMatrix: sphere.transform.transpose.inverse, color: sphere.material.color))
            //
            spherePositions.append(sphere.transform.columns.3.xyz)
            sphereRadii.append(1.0)
            sphereColors.append(sphere.material.color)
        }
        instanceBuffer = device.makeBuffer(bytes: instanceData, length: MemoryLayout<InstanceData>.stride*instanceData.count)!
        
        let positionSize = MemoryLayout<SIMD3<Float>>.stride * spherePositions.count
        spherePositionsBuffer = device.makeBuffer(bytes: spherePositions, length: positionSize, options: [])
               
        let radiusSize = MemoryLayout<Float>.stride * sphereRadii.count
        sphereRadiiBuffer = device.makeBuffer(bytes: sphereRadii, length: radiusSize, options: [])
               
        let colorSize = MemoryLayout<SIMD4<Float>>.stride * sphereColors.count
        sphereColorsBuffer = device.makeBuffer(bytes: sphereColors, length: colorSize, options: [])
        super.init()
 
        
    }
    
    
    
    func drawSpheresUsingInstancing( viewProjMat: inout float4x4, in renderCommandEncoder:MTLRenderCommandEncoder){
        renderCommandEncoder.setRenderPipelineState(instancingRenderPipelineState)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
        
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)

        renderCommandEncoder.setVertexBuffer(self.world.sphereMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(self.instanceBuffer,offset: 0,index: 1)
        renderCommandEncoder.setVertexBytes(&viewProjMat, length: MemoryLayout<float4x4>.size, index: 2)
        
        for submesh in self.world.sphereMesh.submeshes{
            renderCommandEncoder.setTriangleFillMode(.fill)
            renderCommandEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset,
                instanceCount: self.world.Spheres.count
            )
        }
                
        
        
    }
    
    func drawSpheresUsingRayIntersect(
        viewportSize: inout SIMD2<Float>,
        viewMat: inout float4x4,
        projMat: inout float4x4,
        cameraPos: inout SIMD3<Float>,
        in renderCommandEncoder:MTLRenderCommandEncoder){
        
        renderCommandEncoder.setRenderPipelineState(raySphereRenderPipelineState)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
            
        var invProjMat = projMat.inverse
//            print("projMat: \(projMat) inv: \(invProjMat)")
//        var proj
            
//            print("projM")
        
        // add sphere data to the vertex shader
        renderCommandEncoder.setVertexBuffer(spherePositionsBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(sphereRadiiBuffer, offset: 0, index: 1)
        renderCommandEncoder.setVertexBuffer(sphereColorsBuffer, offset: 0, index: 2)
            renderCommandEncoder.setVertexBytes(&viewMat, length: MemoryLayout<float4x4>.stride, index: 3)
            renderCommandEncoder.setVertexBytes(&projMat, length: MemoryLayout<float4x4>.stride, index: 4)
            
        
            
        // pass camera position to the fragment shader
        renderCommandEncoder.setFragmentBytes(&cameraPos, length: MemoryLayout<SIMD3<Float>>.stride, index: 1)
        renderCommandEncoder.setFragmentBytes(&viewportSize, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)
            renderCommandEncoder.setFragmentBytes(&invProjMat, length: MemoryLayout<float4x4>.stride, index: 3)
        
            renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4,instanceCount: self.world.Spheres.count)
    }
    
    func drawSphereUsingMeshShader(viewProjMat: inout float4x4, in renderCommandEncoder:MTLRenderCommandEncoder){
        
        renderCommandEncoder.setRenderPipelineState(meshShaderRenderPipelineState)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        
        renderCommandEncoder.setObjectBuffer(self.instanceBuffer, offset: 0, index: 1)
        renderCommandEncoder.setObjectBytes(&viewProjMat, length:  MemoryLayout<float4x4>.stride, index: 2)
        
        renderCommandEncoder.setMeshBytes(&viewProjMat, length:  MemoryLayout<float4x4>.stride, index: 2)
  
        // Setting the number of threads
        let threadsPerGrid = MTLSize(width: self.world.Spheres.count, height: 1, depth: 1)
        let threadsPerObjectThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        let threadsPerMeshThreadgroup = MTLSize(width: 121, height: 1, depth: 1)
        
        renderCommandEncoder.drawMeshThreads(threadsPerGrid, threadsPerObjectThreadgroup: threadsPerObjectThreadgroup, threadsPerMeshThreadgroup: threadsPerMeshThreadgroup)
    }


        
    
    
    
    //
    class func makeDepthStencilState(device:MTLDevice)->MTLDepthStencilState{
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .less
        depthStateDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor:depthStateDescriptor)!
        
    }
    

    
    class func makeRenderPipelineState(devive:MTLDevice, library: MTLLibrary,vertexDescriptor:MDLVertexDescriptor)  throws -> MTLRenderPipelineState{
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.rasterSampleCount = 4
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        // set up culling
        
        let metalVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        metalVertexDescriptor?.layouts[1].stepFunction = .perInstance
        metalVertexDescriptor?.layouts[1].stepRate = 1
        
        pipelineDescriptor.vertexDescriptor = metalVertexDescriptor
        
        
        return try devive.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    
    class func makeRaySphereRenderPipelineState(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState{
        let raySphereVertexFunction = library.makeFunction(name: "vertexShader")!
        let raySphereFragFunction = library.makeFunction(name: "fragmentShader")!
        
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = raySphereVertexFunction
        pipelineDescriptor.fragmentFunction = raySphereFragFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.rasterSampleCount = 4
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Create a vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
            
        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
            
        // Normal attribute
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
            
        // Set stride for each vertex
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        
        do{
            let ps = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return ps
        }catch let error{
            print("Failed to create pipeline state, error: \(error)")
                    throw RendererInitError(description: "failed to create render pipeline state")
        }
                
    }
    
    class func makeMeshShaderRenderPipelineState(device: MTLDevice,library: MTLLibrary) throws -> MTLRenderPipelineState{
        let objectStageFunction = library.makeFunction(name: "objectStage")!
        let meshStageFunction = library.makeFunction(name: "meshStage")!
        let fragShaderFunction = library.makeFunction(name: "fragmShader")!
        
        let pipelineDescriptor = MTLMeshRenderPipelineDescriptor()
        
        pipelineDescriptor.objectFunction = objectStageFunction
        pipelineDescriptor.meshFunction = meshStageFunction
        pipelineDescriptor.fragmentFunction = fragShaderFunction
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.rasterSampleCount = 4
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do{
            let (ps,_) = try device.makeRenderPipelineState(descriptor: pipelineDescriptor,options: MTLPipelineOption())
            return ps
        }catch let error{
            print("Failed to create pipeline state:\(error)")
            throw RendererInitError(description: "Failed to create mesh shader render pipeline state")
        }

        
        
    }
    
    
    
    var vertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        
        // per-vertex attributes
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 6)
        
        // per-instance attributes
        // 4x4 model matrix
            vertexDescriptor.attributes[2] = MDLVertexAttribute(name: "instance_modelMatrix", format: .float4, offset: 0, bufferIndex: 1)
            vertexDescriptor.attributes[3] = MDLVertexAttribute(name: "instance_modelMatrix", format: .float4, offset: MemoryLayout<Float>.size * 4, bufferIndex: 1)
            vertexDescriptor.attributes[4] = MDLVertexAttribute(name: "instance_modelMatrix", format: .float4, offset: MemoryLayout<Float>.size * 8, bufferIndex: 1)
            vertexDescriptor.attributes[5] = MDLVertexAttribute(name: "instance_modelMatrix", format: .float4, offset: MemoryLayout<Float>.size * 12, bufferIndex: 1)
        // 4x4 normal matrix
        
            vertexDescriptor.attributes[6] = MDLVertexAttribute(name: "instance_normalMatrix", format: .float4, offset: MemoryLayout<Float>.size * 16, bufferIndex: 1)
            vertexDescriptor.attributes[7] = MDLVertexAttribute(name: "instance_normalMatrix", format: .float4, offset: MemoryLayout<Float>.size * 20, bufferIndex: 1)
            vertexDescriptor.attributes[8] = MDLVertexAttribute(name: "instance_normalMatrix", format: .float4, offset: MemoryLayout<Float>.size * 24, bufferIndex: 1)
            vertexDescriptor.attributes[9] = MDLVertexAttribute(name: "instance_normalMatrix", format: .float4, offset: MemoryLayout<Float>.size * 28, bufferIndex: 1)
            vertexDescriptor.attributes[10] = MDLVertexAttribute(name: "instance_color", format: .float4, offset: MemoryLayout<Float>.size * 32, bufferIndex: 1)
        
            vertexDescriptor.layouts[1] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 36)
        

        return vertexDescriptor
    }()
    
    
    
}

