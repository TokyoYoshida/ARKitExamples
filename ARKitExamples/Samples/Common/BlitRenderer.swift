//
//  Renderer.swift
//  ARKitExamples
//
//  Created by TokyoYoshida on 2021/07/19.
//

import ARKit
import Metal
import MetalKit
import CoreImage

class BlitRenderer {
    private let device: MTLDevice
    private var renderPipeline: MTLRenderPipelineState!

    init(device: MTLDevice) {
        func buildPipeline() {
            guard let library = device.makeDefaultLibrary() else {fatalError()}
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "compositeImageVertexTransform")
            descriptor.fragmentFunction = library.makeFunction(name: "compositeImageFragmentShader")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
        }

        self.device = device
        buildPipeline()
    }
    
    func update(_ commandBuffer: MTLCommandBuffer, texture: MTLTexture, destTexture: MTLTexture) {

        let w = min(texture.width, destTexture.width)
        let h = min(texture.height, destTexture.height)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        blitEncoder.copy(from: texture,
                          sourceSlice: 0,
                          sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x:0, y:0 ,z:0),
                          sourceSize: MTLSizeMake(w, h, texture.depth),
                          to: destTexture,
                          destinationSlice: 0,
                          destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x:0, y:0 ,z:0))
        
        blitEncoder.endEncoding()

    }
}
