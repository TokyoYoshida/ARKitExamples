//
//  ViewController.swift
//  ExampleOfiOSLiDAR
//
//  Created by TokyoYoshida on 2021/01/07.
//

import ARKit
import Metal
import MetalKit
import CoreImage

class HumanStencilViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var mtkView: MTKView!
    
    // ARKit
    private var session: ARSession!
    var alphaTexture: MTLTexture?

    // Metal
    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue!
    private var matteGenerator: ARMatteGenerator!
    lazy private var textureCache: CVMetalTextureCache = {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        return cache!
    }()

    private var texture: MTLTexture!
    lazy private var renderer = HumanStencilRenderer(device: device, preferredFramesTime: Float(mtkView.preferredFramesPerSecond))
    lazy private var blitRenderer = BlitRenderer(device: device)

    // Human Stencil
    lazy private var ycbcrConverter = YCbCrToRGBConverter(device, session: session, view: mtkView)
    private var storedCameraTexture: MTLTexture?
    private var requestStoreCameraTexture: Bool = false

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
            mtkView.framebufferOnly = false
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
        func createTexture() {
            let width = mtkView.currentDrawable!.texture.width
            let height = mtkView.currentDrawable!.texture.height

            let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: mtkView.colorPixelFormat,
                                                                 width: height, height: width, mipmapped: false)
            colorDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)

            storedCameraTexture =  device.makeTexture(descriptor: colorDesc)
        }
        func initGesture() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedScreen(_:)))
            tapGesture.delegate = self
            self.view.addGestureRecognizer(tapGesture)
        }
        super.viewDidLoad()
        initARSession()
        initMatteGenerator()
        initMetal()
        createTexture()
        initGesture()
    }
    
    @objc func tappedScreen(_ sender: UITapGestureRecognizer) {
        func requestStoreCamera() {
            requestStoreCameraTexture = true
        }
        func toggleNavigationBar() {
            let hidden = navigationController?.isNavigationBarHidden ?? false
            let toggled = !hidden
            navigationController?.setNavigationBarHidden(toggled    , animated: true)
            
        }
        requestStoreCamera()
        toggleNavigationBar()
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

        guard let (textureY, textureCbCr) = session.currentFrame?.buildCapturedImageTextures(textureCache: textureCache) else {return}

        ycbcrConverter.compositeImagesWithEncoder(commandBuffer, textureY: textureY, textureCbCr: textureCbCr)
                
        guard let cameraTexture = ycbcrConverter.sceneColorTexture else {return}
        
        guard let alphaTexture = getAlphaTexture(commandBuffer) else {return}
        renderer.update(commandBuffer, cameraTexture: cameraTexture, storedCameraTexture: storedCameraTexture!, alphaTexture: alphaTexture, drawable: drawable)
        
        if requestStoreCameraTexture {
            requestStoreCameraTexture = false
            blitRenderer.update(commandBuffer, texture: cameraTexture, destTexture: storedCameraTexture as! MTLTexture)
        }
        
        
        commandBuffer.present(drawable)
        
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
        let image = CIImage(mtlTexture: storedCameraTexture!, options:nil)
    }
}

extension HumanStencilViewController: ARSessionDelegate {
}
