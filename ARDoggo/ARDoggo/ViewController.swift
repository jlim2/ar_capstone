//
//  ViewController.swift
//  ARDoggo
//
//  Created by LimJJ on 10/30/18.
//  Copyright © 2018 JJ Lim. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    // Set up global variables
    @IBOutlet var sceneView: ARSCNView!
    var wolf_fur: ColladaRig?
    var tapGestureRecognizer: UITapGestureRecognizer?
    var trackerNode: SCNNode!
    var wolfIsPlaced = false
    var planeIsDetected = false
    var wolf: SCNNode!
    var worldPos: SCNVector3!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set the debuging options
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Enable lighting
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        // Recognize tap gesture
        addTapGestureToSceneView()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Horizontal plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Referred: Anyone Can Code ARGame Tutorial - Part 2 of 3 (www.youtube.com/watch?v=mOTrialE85Q)
        // Return if plane is not detected
        if wolfIsPlaced {
            //do things with wolf
        }
        else {
            guard planeIsDetected else { return }
            trackerNode.removeFromParentNode()
            wolfIsPlaced = true
            wolf = sceneView.scene.rootNode.childNode(withName: "wolf", recursively: true)!
            wolf.isHidden = false
            wolf.position = worldPos
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                            Renderers                                /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Override to create and configure nodes for anchors added to the view's session.
    // Visualize horizontal planes refer: https://www.appcoda.com/arkit-horizontal-plane/
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Unwrap the anchor as an ARPlaneAnchor
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Get the anchor dimension
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        // Set the color of the plane
        plane.materials.first?.diffuse.contents = UIColor.magenta
        
        // Initialize a SCNNode with the geometry we got
        let planeNode = SCNNode(geometry: plane)
        
        // Initialize coordinates of the plane
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
        
        // Add the plane node as a SceneKit
        node.addChildNode(planeNode)
    }
    
    // Renderer to expand the horizontal planes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // 1) Unwrap the plane anchor as ARPlaneAnchor
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first, // 2) Unwrap the first plane node
            let plane = planeNode.geometry as? SCNPlane // 3) Unwrap the node geometry
            else { return }
        
        // 2) Update plane geometry
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        // 3) Update plane coordinates
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x, y, z)
    }
    
    // Look for a surface to place wolf
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Referred: Anyone Can Code ARKit Game Tutorial - Part 1 of 3
        guard !wolfIsPlaced else { return }
        
        // Do the hit test in the middle of the screen and get the closest hit test result if pass
        guard let hitTest = sceneView.hitTest(
            CGPoint(x: view.frame.midX, y: view.frame.midY),
            types: [.featurePoint, .existingPlane]
            )
            .first
            else { return }
        
        
        // With the farthest hit test result, get the transformation matrix
        let transMat = SCNMatrix4(hitTest.worldTransform)
        worldPos = SCNVector3Make(transMat.m41, transMat.m42, transMat.m43)
        
        if !planeIsDetected { // only runs once
            let trackerPlane = SCNPlane(width: 0.5, height: 0.5)
            trackerPlane.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "corgiTracker")
            trackerNode = SCNNode(geometry: trackerPlane)
            
//            trackerNode.rotation = SCNVector4(0, yaw ?? 0, 0, 0)
            trackerNode.eulerAngles.x = -.pi/2.0 // make tracker horizontal
            planeIsDetected = true
        }
        
        // runs constantly
        trackerNode.position = worldPos
        let yaw = sceneView.session.currentFrame?.camera.eulerAngles.y
        trackerNode.eulerAngles.y = yaw!
        sceneView.scene.rootNode.addChildNode(trackerNode)
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                        Using .dae model                             /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Add model from a Collada file to the scene
    @objc func addColladaModelToSceneView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let hitPos = getHitTestPosVec(withGestureRecognizer: recognizer)
        setupColladaModel(position: hitPos)
        print(hitPos)
    }
    // Set up animation and model of a collada (.dae) model using ColladaRig.swift
    func setupColladaModel(position: SCNVector3) {
        // Referred:
        //     GameViewController.swift
        //     RunningMan
        //     Created by Oliver Dew on 01/06/2016.
        //     Copyright (c) 2016 Salt Pig. All rights reserved.
        
        wolf_fur = ColladaRig(modelNamed: "Wolf_obj_fur" , daeNamed: "wolf_dae", position: position)
        wolf_fur!.loadAnimation(withKey: "run2", daeNamed: "wolf_dae")
        sceneView.scene.rootNode.addChildNode(wolf_fur!.modelNode)
        //TODO: fix model's position only being origin
    }
    
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                       Using .scn model                              /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    @objc func addModelToSceneView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        // Use the tap location to determine if on a plane
        let hitPos = getHitTestPosVec(withGestureRecognizer: recognizer)
        
        // Extract wolf scene from .scn file and set up wolf node
        let wolfScene = SCNScene(named: "art.scnassets/wolf.scn")!
        let wolfNode = wolfScene.rootNode.childNode(withName: "wolf", recursively: true)!
        wolfNode.removeAllAnimations()
        wolfNode.removeAllActions()
        
        // Rotate the node according to camera (only horizontally)
        // referred: https://stackoverflow.com/questions/46390019/how-to-change-orientation-of-a-scnnode-to-the-camera-with-arkit
        let yaw = sceneView.session.currentFrame?.camera.eulerAngles.y
        // place right behind where the user tapped
        wolfNode.position = worldPos
        wolfNode.rotation = SCNVector4(0, 1, 0, yaw ?? 0)
        // Place the wolf a bit "behind" where the user taps
        wolfNode.localTranslate(by: SCNVector3(0, -0.1, -0.3))
        // Display wolf with "normal" orientation. After changing wolf.scn's node
        // names, 90 degrees x-rotation happened (by accident?) and this "fixes" it.
        // If model is fixed to have horizontal orientation, could delete this line.
        if wolfNode.eulerAngles.x > 0 {
            // prevent wolf to be upside down when adding to left to initial camera position
            wolfNode.eulerAngles.x = -.pi/2.0
        }
        else {
            wolfNode.eulerAngles.x = .pi/2.0
        }
        
        // Add wolf to the sceneView so that it is displayed
        sceneView.scene.rootNode.addChildNode(wolfNode)
        
        // Let wolf affected by physics
        wolfNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                          Move wolf                                  /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    func walk(to: SCNVector3) {
        wolf.look(at: to)
        wolf.physicsBody?.applyForce(SCNVector3(0.0, 0.0, 2.0), asImpulse: true)
    }
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                     Hit Test and Tapping                            /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    @objc func getHitTestPosVec(withGestureRecognizer recognizer: UIGestureRecognizer) -> SCNVector3 {
        // Use the tap location to determine if on a plane
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        guard let hitTestResult = hitTestResults.first else { return SCNVector3(0,0,0) } //TODO: think about failure return behavior
        let translation = hitTestResult.worldTransform.columns.3
        let x = translation.x
        let y = translation.y
        let z = translation.z
        //        print("hitTest coord: (",x, y, z, ")") // DEBUG
        
        // Rotate the node according to camera (only horizontally)
        // referred: https://stackoverflow.com/questions/46390019/how-to-change-orientation-of-a-scnnode-to-the-camera-with-arkit
        //        let yaw = sceneView.session.currentFrame?.camera.eulerAngles.y
        
        return SCNVector3(x, y, z)
    }
    
    func addTapGestureToSceneView() {
        // Detect tap gesture
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.addModelToSceneView(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer!)
    }
    
    func getTapGestureRecognizer() -> UITapGestureRecognizer {
        return tapGestureRecognizer!
    }
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////////                            Others                                   /////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}


//ColladaRig stuff
//gestureRecognizers: Optional([
//<UILongPressGestureRecognizer: 0x1042192f0; state = Possible; enabled = NO; cancelsTouchesInView = NO; view = <ARSCNView 0x104211f50>; target= <(action=_handlePress:, target=<SCNCameraNavigationController 0x104218f90>)>>, <UIPanGestureRecognizer: 0x1042197d0; state = Possible; enabled = NO; cancelsTouchesInView = NO; view = <ARSCNView 0x104211f50>; target= <(action=_handlePan:, target=<SCNCameraNavigationController 0x104218f90>)>>,
//<UITapGestureRecognizer: 0x2828fee00; state = Possible; enabled = NO; cancelsTouchesInView = NO; view = <ARSCNView 0x104211f50>; target= <(action=_handleDoubleTap:, target=<SCNCameraNavigationController 0x104218f90>)>; numberOfTapsRequired = 2>, <UIPinchGestureRecognizer: 0x104219660; state = Possible; enabled = NO; cancelsTouchesInView = NO; view = <ARSCNView 0x104211f50>; target= <(action=_handlePinch:, target=<SCNCameraNavigationController 0x104218f90>)>>,
//<UIRotationGestureRecognizer: 0x104219950; state = Possible; enabled = NO; cancelsTouchesInView = NO; view = <ARSCNView 0x104211f50>; target= <(action=_handleRotation:, target=<SCNCameraNavigationController 0x104218f90>)>>, <UITapGestureRecognizer: 0x2828f5b00; state = Ended; view = <ARSCNView 0x104211f50>; target= <(action=addColladaModelToSceneViewWithGestureRecognizer:, target=<ARDoggo.ViewController 0x104210110>)>>])

//sceneSource:  <SCNSceneSource: 0x282718ba0 | URL='file:///var/containers/Bundle/Application/105AE83D-24C2-40D1-BF75-E00E75B38D39/ARDoggo.app/art.scnassets/wolf_dae.dae'>


//identifiersOfEntry
//["Becken", "Maulunten", "Braun_O_R", "Bauch", "Vorderpfote_L", "Mauloben", "Bauch_001", "aug_lied_O_L", "Brust", "Schalterplatte_R", "MundW_L", "Hals", "aug_lied_O_R", "Unterschenkel_L", "Oberarm_R", "MundW_R", "Kopf_002", "aug_lied_U_L", "Kopf", "Unterarm_R", "Aug_R", "Pfote1_L", "aug_lied_U_R", "Pfote2_L", "Vorderpfote_R", "aug_L", "Oberschenkel_R", "Bauch_003", "Schwanz", "Ohr_L", "Unterschenkel_R", "Schalterplatte_L", "Schwanz_001", "Ohr_R", "Pfote1_R", "Oberarm_L", "Schwanz_002", "Pfote2_R", "Unterarm_L", "Schwanz_003", "root", "Oberschenkel_L", "Wolf_obj_fur", "Wolf_obj_body", "Unterkiefer", "node/46", "Hals_fett", "run2", "Braun_O_L"]

