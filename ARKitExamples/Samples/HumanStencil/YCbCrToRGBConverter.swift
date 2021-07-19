//
//  YCbCrToRGBConverter.swift
//  ARKitExamples
//
//  Created by TokyoYoshida on 2021/07/19.
//

import ARKit
import Metal
import MetalKit

class YCbCrToRGBConverter {
    private let device: MTLDevice
    private let view: MTKView
    
//    var renderDestination: RenderDestinationProvider

    private var capturedImagePipelineState: MTLRenderPipelineState!
    private var capturedImageDepthState: MTLDepthStencilState!
    lazy private var textureCache: CVMetalTextureCache = {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        return cache!
    }()

    private let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0
    ]
    private var imagePlaneVertexBuffer: MTLBuffer!
    
    private(set) var sceneColorTexture: MTLTexture!
    private(set) var sceneDepthTexture: MTLTexture!

    let session: ARSession

    init(_ device: MTLDevice, session: ARSession, view: MTKView) {
        func initVertexBuffer() {
            let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
            imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        }

        self.session = session
        self.device = device
        self.view = view

        initVertexBuffer()
    }
    
    func compositeImagesWithEncoder(_ commandBuffer: MTLCommandBuffer, textureY: CVMetalTexture, textureCbCr: CVMetalTexture) {
        func buildRenderEncoer() -> MTLRenderCommandEncoder? {
            guard let sceneRenderDescriptor = view.copy() as? MTLRenderPassDescriptor else {
                fatalError("Unable to create a render pass descriptor.")
            }
            sceneRenderDescriptor.colorAttachments[0].texture = sceneColorTexture
            sceneRenderDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            sceneRenderDescriptor.colorAttachments[0].loadAction = .clear
            sceneRenderDescriptor.colorAttachments[0].storeAction = .store

            sceneRenderDescriptor.depthAttachment.texture = sceneDepthTexture
            sceneRenderDescriptor.depthAttachment.clearDepth = 1.0
            sceneRenderDescriptor.depthAttachment.loadAction = .clear
            sceneRenderDescriptor.depthAttachment.storeAction = .store

            let encoder =  commandBuffer.makeRenderCommandEncoder(descriptor: sceneRenderDescriptor)
            encoder?.label = "YCrCBRenderEncoder"

            return encoder
        }

        guard let renderEncoder = buildRenderEncoer() else {return}


        renderEncoder.pushDebugGroup("DrawCapturedImage")
        
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(capturedImagePipelineState)
        renderEncoder.setDepthStencilState(capturedImageDepthState)
        
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kBufferIndexMeshPositions.rawValue))
        
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureIndexY.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureIndexCbCr.rawValue))
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
}
