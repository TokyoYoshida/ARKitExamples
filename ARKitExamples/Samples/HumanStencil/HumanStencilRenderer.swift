//
//  HumanStencilRenderer.swift
//  ARKitExamples
//
//  Created by TokyoYoshida on 2021/07/19.
//

import ARKit
import Metal
import MetalKit
import CoreImage

class HumanStencilRenderer {
    private let device: MTLDevice
    private var renderPipeline: MTLRenderPipelineState!
    private var imagePlaneVertexBuffer: MTLBuffer!
    private var scenePlaneVertexBuffer: MTLBuffer!

    let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0
    ]

    init(device: MTLDevice) {
        func buildPipeline() {
            guard let library = device.makeDefaultLibrary() else {fatalError()}
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "compositeImageVertexTransform")
            descriptor.fragmentFunction = library.makeFunction(name: "compositeImageFragmentShader")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
        }
        func buildBuffers() {
            let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
            imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"

            scenePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            scenePlaneVertexBuffer.label = "ScenePlaneVertexBuffer"
        }

        self.device = device
        buildPipeline()
        buildBuffers()
    }
    
    func update(_ commandBuffer: MTLCommandBuffer, cameraTexture: MTLTexture, textureY: MTLTexture, textureCbCr: MTLTexture,alphaTexture: MTLTexture, drawable: CAMetalDrawable) {
        
        let renderPassDescriptor: MTLRenderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        guard let renderPipeline = renderPipeline else {fatalError()}

        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(scenePlaneVertexBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(cameraTexture, index: 0)
        renderEncoder.setFragmentTexture(textureY, index: 1)
        renderEncoder.setFragmentTexture(textureCbCr, index: 2)
        renderEncoder.setFragmentTexture(alphaTexture, index: 3)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.endEncoding()
    }
}
