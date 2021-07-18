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
            commandQueue = device.makeCommandQueue()
            mtkView.device = device
            mtkView.delegate = self
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
        loadTexture()
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
        guard let drawable = view.currentDrawable else {return}
        
        let commandBuffer = commandQueue.makeCommandBuffer()!

        guard let alphaTexture = getAlphaTexture(commandBuffer) else {return}
     
        let w = min(alphaTexture.width, drawable.texture.width)
        let h = min(alphaTexture.height, drawable.texture.height)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        blitEncoder.copy(from: alphaTexture,
                          sourceSlice: 0,
                          sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x:0, y:0 ,z:0),
                          sourceSize: MTLSizeMake(w, h, alphaTexture.depth),
                          to: drawable.texture,
                          destinationSlice: 0,
                          destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x:0, y:0 ,z:0))
        
        blitEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        commandBuffer.commit()
    }
}

extension HumanStencilViewController: ARSessionDelegate {
}
