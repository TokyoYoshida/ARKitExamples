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
    private var uniforms = Uniforms(time: Float(0.0))
    var preferredFramesTime: Float!

    let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0
    ]

    init(device: MTLDevice, preferredFramesTime: Float) {
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
        }

        self.device = device
        self.preferredFramesTime = preferredFramesTime
        buildPipeline()
        buildBuffers()
    }
    
    func update(_ commandBuffer: MTLCommandBuffer, cameraTexture: MTLTexture, storedCameraTexture: MTLTexture, alphaTexture: MTLTexture, drawable: CAMetalDrawable) {
        
        uniforms.time += preferredFramesTime

        let renderPassDescriptor: MTLRenderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        guard let renderPipeline = renderPipeline else {fatalError()}

        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(cameraTexture, index: 0)
        renderEncoder.setFragmentTexture(alphaTexture, index: 1)
        renderEncoder.setFragmentTexture(storedCameraTexture, index: 2)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.endEncoding()
    }
}
