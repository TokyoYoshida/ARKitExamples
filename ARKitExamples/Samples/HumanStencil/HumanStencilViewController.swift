//
//  ViewController.swift
//  ExampleOfiOSLiDAR
//
//  Created by TokyoYoshida on 2021/01/07.
//

import ARKit
import Metal
import MetalKit

class HumanStencilViewController: UIViewController {
    // ARKit
    private var session: ARSession!
    var alphaTexture: MTLTexture?

    // Metal
    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue!
    private var matteGenerator: ARMatteGenerator!
    private var renderPipeline: MTLRenderPipelineState!
    lazy private var textureCache: CVMetalTextureCache = {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        return cache!
    }()

    private var texture: MTLTexture!
    var mtkView: MTKView {
        return view as! MTKView
    }

    var orientation: UIInterfaceOrientation {
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
            fatalError()
        }
        return orientation
    }

    override func viewDidLoad() {
        func initMatteGenerator() {
            matteGenerator = ARMatteGenerator(device: device, matteResolution: .half)
        }
        func loadTexture() {
            let textureLoader = MTKTextureLoader(device: device)
            texture = try! textureLoader.newTexture(name: "fuji", scaleFactor: view.contentScaleFactor, bundle: nil)
            mtkView.colorPixelFormat = texture.pixelFormat
            mtkView.framebufferOnly = false
        }
        func initMetal() {
            func buildPipeline() {
                guard let library = device.makeDefaultLibrary() else {fatalError()}
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "compositeImageVertexTransform")
                descriptor.fragmentFunction = library.makeFunction(name: "compositeImageFragmentShader")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
                renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
            }
            commandQueue = device.makeCommandQueue()
            mtkView.device = device
            mtkView.delegate = self
            buildPipeline()
        }
        func runARSession() {
            let configuration = ARWorldTrackingConfiguration()

            configuration.frameSemantics = .personSegmentationWithDepth

            session.run(configuration)
        }
        func initARSession() {
            session = ARSession()
            session.delegate = self
            runARSession()
        }
        super.viewDidLoad()
        initARSession()
        initMatteGenerator()
        initMetal()
    }
}

extension HumanStencilViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        func getAlphaTexture(_ commandBuffer: MTLCommandBuffer) -> MTLTexture? {
            guard let currentFrame = session.currentFrame else {
                return nil
            }

            return matteGenerator.generateMatte(from: currentFrame, commandBuffer: commandBuffer)
        }
        func buildRenderEncoder(_ commandBuffer: MTLCommandBuffer) -> MTLRenderCommandEncoder? {
            let rpd = view.currentRenderPassDescriptor
            rpd?.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 0, 1)
            rpd?.colorAttachments[0].loadAction = .clear
            rpd?.colorAttachments[0].storeAction = .store
            return commandBuffer.makeRenderCommandEncoder(descriptor: rpd!)
        }
        guard let drawable = view.currentDrawable else {return}
        
        let commandBuffer = commandQueue.makeCommandBuffer()!

//        guard let tex = getAlphaTexture(commandBuffer) else {return}
        guard let tex = session.currentFrame?.capturedImage.createTexture(pixelFormat: mtkView.colorPixelFormat , planeIndex: 0, capturedImageTextureCache: textureCache) else {return}
        
        guard let (textureY, textureCbCr) = session.currentFrame?.buildCapturedImageTextures(textureCache: textureCache) else {return}
     
        guard let renderPipeline = renderPipeline else {return}
        guard let renderEncoder = buildRenderEncoder(commandBuffer) else {return}

        renderEncoder.setRenderPipelineState(renderPipeline)
//        renderEncoder.setVertexBuffer(vertextBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: 1)
        renderEncoder.setFragmentTexture(alphaTexture, index: 2)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

//        let w = min(tex.width, drawable.texture.width)
//        let h = min(tex.height, drawable.texture.height)
//        
//        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
//        
//        blitEncoder.copy(from: tex,
//                          sourceSlice: 0,
//                          sourceLevel: 0,
//                          sourceOrigin: MTLOrigin(x:0, y:0 ,z:0),
//                          sourceSize: MTLSizeMake(w, h, tex.depth),
//                          to: drawable.texture,
//                          destinationSlice: 0,
//                          destinationLevel: 0,
//                          destinationOrigin: MTLOrigin(x:0, y:0 ,z:0))
//        
//        blitEncoder.endEncoding()
//        
        commandBuffer.present(drawable)
        
        commandBuffer.commit()
    }
}

extension HumanStencilViewController: ARSessionDelegate {
}
