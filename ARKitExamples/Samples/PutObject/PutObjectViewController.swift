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

class PutObjectViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        func initARScene() {
            sceneView.scene = SCNScene(named: "art.scnassets/ship.scn")!

            let configuration = ARWorldTrackingConfiguration()
            
            sceneView.session.run(configuration)
        }
        super.viewDidLoad()

        initARScene()
    }
}
