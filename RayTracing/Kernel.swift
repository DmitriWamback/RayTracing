//
//  Kernel.swift
//  RayTracing
//
//  Created by Dmitri Wamback on 2023-06-05.
//

import Foundation
import Metal
import MetalKit
import simd

struct __uniforms {
    var windowSize: SIMD2<Float>!
}

class ComputeKernel {
    
    var c_pipeline: MTLComputePipelineState!
    var texture:    MTLTexture!
    
    func use(drawable: CAMetalDrawable?, renderable: ComputeRenderable) {
        
        let cmdBuffer = ctx.cmdqueue.makeCommandBuffer()
        guard let computeEncoder = cmdBuffer?.makeComputeCommandEncoder() else { return }
        
        computeEncoder.setComputePipelineState(c_pipeline)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBytes(&renderable.uniforms, length: MemoryLayout<__uniforms>.stride, index: 1)
        computeEncoder.dispatchThreads(MTLSize(width:   Int(renderable.uniforms.windowSize.x),
                                               height:  Int(renderable.uniforms.windowSize.y), depth: 1),
                                               threadsPerThreadgroup: MTLSize(width: 10, height: 10, depth: 1))
        computeEncoder.endEncoding()
        
        cmdBuffer?.present(drawable!)
        cmdBuffer?.commit()
    }
}

class ComputeRenderable {
    
    var vertices: [Float]!
    var uniforms: __uniforms!
    
    init(initialWindowScale: NSRect) {
        
        var u = __uniforms()
        u.windowSize = SIMD2<Float>(Float(initialWindowScale.width), Float(initialWindowScale.height))
        
        self.sendVertexData(vertices: [-1.0, -1.0, 0.0,
                                        1.0, -1.0, 0.0,
                                        1.0,  1.0, 0.0,
                                        1.0,  1.0, 0.0,
                                       -1.0,  1.0, 0.0,
                                       -1.0, -1.0, 0.0], uniform: u)
    }
    
    func sendVertexData(vertices: [Float], uniform: __uniforms) {
        self.vertices = vertices
        self.uniforms = uniform
    }
    
    func renderAndDraw(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setVertexBuffer(self.makeVertexBuffer(), offset: 0, index: 0)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<__uniforms>.stride, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    private func makeVertexBuffer() -> MTLBuffer {
        let vSize = vertices.count * MemoryLayout.size(ofValue: vertices[0])
        return ctx.device.makeBuffer(bytes: vertices, length: vSize)!
    }
}
