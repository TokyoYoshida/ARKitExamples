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
            sceneView.delegate = self

            sceneView.scene = SCNScene()
            
            sceneView.debugOptions = [.showFeaturePoints]
            sceneView.automaticallyUpdatesLighting = true
            sceneView.autoenablesDefaultLighting = true

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            
            sceneView.session.run(configuration)
        }
        super.viewDidLoad()

        initARScene()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let touchPos = touch.location(in: sceneView)
        
        guard let query = sceneView.raycastQuery(from: touchPos, allowing: .estimatedPlane, alignment: .any) else { return  }
        let result = sceneView.session.raycast(query)
        if !result.isEmpty {
            let anchor = ARAnchor(transform: result.first!.worldTransform)
            sceneView.session.add(anchor: anchor)
        }
    }
}

extension PutObjectViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        
        let sphereNode = SCNNode()
        
        sphereNode.geometry = SCNSphere(radius: 0.05)
        sphereNode.position.y += Float(0.05)
        
        node.addChildNode(sphereNode)
    }
    
}
