//
//  RenderView.swift
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/22/24.
//

import SwiftUI
import MetalKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformView = NSView
#else
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformView = UIView
#endif


struct RenderView: PlatformViewRepresentable{
    typealias PlatformViewType = MTKView
    
    
    let SampleCount :Int  = 4
    let ColorPixelFormat = MTLPixelFormat.bgra8Unorm
    let DepthStencilPixelFormat = MTLPixelFormat.depth32Float
    let PreferredFPS : Int = 60
    let EnableSetNeedsDisplay : Bool = true
    
    
    func makeCoordinator() -> Render {
        Render(self)
    }
    
#if os(macOS)
    func makeNSView(context: Context) ->  MTKView {
        return createMTKView(context: context)
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        
    }
#else
    func makeUIView(context: Context) -> MTKView{
        return createMTKView(context:context)
    }
    func updateUIView(_ uiView: MTKView, context: Context) {
        
    }
#endif
    
    func createMTKView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = PreferredFPS
        mtkView.enableSetNeedsDisplay = EnableSetNeedsDisplay
        mtkView.sampleCount = SampleCount
        mtkView.colorPixelFormat = ColorPixelFormat
        mtkView.depthStencilPixelFormat = DepthStencilPixelFormat
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        mtkView.isPaused = false
        
        return mtkView
    }
    

}

#Preview {
    RenderView()
}

