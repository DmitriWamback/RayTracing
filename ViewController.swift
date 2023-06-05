//
//  ViewController.swift
//  RayTracing
//
//  Created by Dmitri Wamback on 2023-06-05.
//

import Cocoa
import Metal
import MetalKit
import simd

struct mtlctx {
    var device:             MTLDevice!
    var pipeline:           MTLRenderPipelineState!
    var cmdqueue:           MTLCommandQueue!
    var mtkview:            MTKView!
}
var ctx: mtlctx = mtlctx()

class ViewController: NSViewController {
    
    var libraries: Dictionary<String, MTLRenderPipelineDescriptor>!
    
    var debugKernel: ComputeKernel!
    var debugRenderable: ComputeRenderable!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        libraries = Dictionary<String, MTLRenderPipelineDescriptor>()
        ctx.device = MTLCreateSystemDefaultDevice()
        ctx.cmdqueue = ctx.device.makeCommandQueue()
        ctx.mtkview = MTKView(frame: NSRect(x: 0, y: 0, width: 1300, height: 1300))
        preferredContentSize = ctx.mtkview.frame.size
        
        ctx.mtkview.delegate = self
        ctx.mtkview.device = ctx.device
        view.addSubview(ctx.mtkview)
        view.frame.size = ctx.mtkview.frame.size
        
        let library = createRenderPipelineDescriptor(libraryName: "_base1", vertexFunctionName: "vMain", fragmentFunctionName: "fMain")
        debugKernel = createComputePipelineDescriptorWithKernel(library: library, computeKernelFunctionName: "cMain")
        
        debugRenderable = ComputeRenderable(initialWindowScale: self.view.frame)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController: MTKViewDelegate {
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        
        guard let drawable = view.currentDrawable else { return }
        
        let renderpassDescriptor = MTLRenderPassDescriptor()
        renderpassDescriptor.colorAttachments[0].texture = drawable.texture
        renderpassDescriptor.colorAttachments[0].loadAction = .clear
        renderpassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let commandBuffer = ctx.cmdqueue.makeCommandBuffer() else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderpassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(ctx.pipeline)
        renderEncoder.setFragmentTexture(debugKernel.texture, index: 0)
        debugRenderable.renderAndDraw(renderEncoder: renderEncoder)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        debugKernel.use(drawable: drawable, renderable: debugRenderable)
    }
    
    func createComputePipelineDescriptorWithKernel(library: MTLLibrary, computeKernelFunctionName: String) -> ComputeKernel {
        
        let compute = library.makeFunction(name: computeKernelFunctionName)
        let kernel = ComputeKernel()
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.storageMode   = .private
        textureDescriptor.usage         = [.shaderRead, .shaderWrite]
        textureDescriptor.pixelFormat   = .rgba32Float
        textureDescriptor.width         = Int(self.view.frame.width)
        textureDescriptor.height        = Int(self.view.frame.height)
        textureDescriptor.depth         = 1
        kernel.texture = ctx.device.makeTexture(descriptor: textureDescriptor)
        
        do {
            kernel.c_pipeline = try ctx.device.makeComputePipelineState(function: compute!)
        }
        catch { print(error) }
        
        return kernel
    }
    
    func createRenderPipelineDescriptor(libraryName: String, vertexFunctionName: String, fragmentFunctionName: String) -> MTLLibrary {
        
        let library = ctx.device.makeDefaultLibrary()
        let vertex  = library?.makeFunction(name: vertexFunctionName)
        let fragment = library?.makeFunction(name: fragmentFunctionName)
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        ctx.pipeline = try! ctx.device.makeRenderPipelineState(descriptor: descriptor)
        
        libraries[libraryName] = descriptor
        return library!
    }
}
