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
    
    private lazy var width = view.currentDrawable!.texture.width
    private lazy var height = view.currentDrawable!.texture.height

    private(set) var sceneColorTexture: MTLTexture!
    private(set) var sceneDepthTexture: MTLTexture!

    let session: ARSession

    init(_ device: MTLDevice, session: ARSession, view: MTKView) {
        func createVertexBuffer() {
            let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
            imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        }
        func createTextures() {
            let width = view.currentDrawable!.texture.width
            let height = view.currentDrawable!.texture.height

            let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: view.colorPixelFormat,
                                                                 width: width, height: height, mipmapped: false)
            colorDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)

            sceneColorTexture =  device.makeTexture(descriptor: colorDesc)

            let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: view.depthStencilPixelFormat,
                                                                 width: width, height: height, mipmapped: false)
            depthDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)

            sceneDepthTexture = device.makeTexture(descriptor: depthDesc)
        }
        func createPipelineState() {
            let defaultLibrary = device.makeDefaultLibrary()!
            let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "capturedImageVertexTransform")!
            let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "capturedImageFragmentShader")!

            let imagePlaneVertexDescriptor = MTLVertexDescriptor()
            
            imagePlaneVertexDescriptor.attributes[0].format = .float2
            imagePlaneVertexDescriptor.attributes[0].offset = 0
            imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
            
            imagePlaneVertexDescriptor.attributes[1].format = .float2
            imagePlaneVertexDescriptor.attributes[1].offset = 8
            imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
            
            imagePlaneVertexDescriptor.layouts[0].stride = 16
            imagePlaneVertexDescriptor.layouts[0].stepRate = 1
            imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex

            let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
            capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
            capturedImagePipelineStateDescriptor.sampleCount = view.sampleCount
            capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
            capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
            capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
            capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
            
            do {
                try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
            } catch let error {
                print("Failed to created captured image pipeline state, error \(error)")
            }
        }
        func createDepthState() {
            let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
            capturedImageDepthStateDescriptor.depthCompareFunction = .always
            capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
            capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)
        }

        self.session = session
        self.device = device
        self.view = view

        createVertexBuffer()
        createTextures()
        createPipelineState()
        createDepthState()
    }
    
    func compositeImagesWithEncoder(_ commandBuffer: MTLCommandBuffer, textureY: CVMetalTexture, textureCbCr: CVMetalTexture) {
        func buildRenderEncoer() -> MTLRenderCommandEncoder? {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let sceneRenderDescriptor = renderPassDescriptor.copy() as? MTLRenderPassDescriptor else {
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
        
        renderEncoder.endEncoding()
    }
}
