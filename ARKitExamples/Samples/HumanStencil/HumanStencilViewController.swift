//
//  ViewController.swift
//  ExampleOfiOSLiDAR
//
//  Created by TokyoYoshida on 2021/01/07.
//

import RealityKit
import MetalKit

class HumanStencilViewController: UIViewController {
    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue!
    
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
            loadTexture()
        }
        super.viewDidLoad()
        initMetal()

    }
}

extension HumanStencilViewController: MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {return}
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
     
        let w = min(texture.width, drawable.texture.width)
        let h = min(texture.height, drawable.texture.height)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        blitEncoder.copy(from: texture,
                          sourceSlice: 0,
                          sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x:0, y:0 ,z:0),
                          sourceSize: MTLSizeMake(w, h, texture.depth),
                          to: drawable.texture,
                          destinationSlice: 0,
                          destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x:0, y:0 ,z:0))
        
        blitEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        commandBuffer.commit()
    }
}

