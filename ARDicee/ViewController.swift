//
//  ViewController.swift
//  ARDicee
//  A simple app to roll dice in AR
//  Created by Justin Rose on 6/10/19.
//  Copyright © 2019 Justin Rose. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var allDiceNodes = [SCNNode]()
    var gridNode: SCNNode? //store the gridNode so we can remove it after placing the first dice
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        //show the feature points ARKit is using to detect a plane
//        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        sceneView.autoenablesDefaultLighting = true //add lighting so we can tell the shape is 3D
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration - immersive AR for A9 chips and higher
        //AROrientationTrackingConfiguration is the alternative for older devices - not a full AR experience
        //Use ARWorldTrackingConfiguration.isSupported bool to test if supported
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = .horizontal //add horizontal plane detection
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    //MARK: Dice Rendering Methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if let touch = touches.first {
            let touchLocation = touch.location(in: sceneView) //get the location of the touch, which is the first object in the touches array
            
            //the hitTest() method converts the 2D touch point on the screen to a 3D point on a real world plane. By using .existingPlaneUsingExtent, we want a point on a real world plane already detected with planeDetection
            let results = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent) //results is an array of ARHitTestResults. If the array is empty, we touched outside of an existing detected plane
            
            //hitResult will only be assigned if we touch inside a detected plane
            guard let hitResult = results.first else {return}
            
            addDice(atLocation: hitResult)
            
        }
    }
    
    //This function will add a dice at the touch point, and then roll the dice
    func addDice(atLocation location: ARHitTestResult) {
        
        // Create a new scene
        let diceScene = SCNScene(named: "art.scnassets/diceCollada.scn")! //scn file created from dae file
        
        if let diceNode = diceScene.rootNode.childNode(withName: "Dice", recursively: true) { //recursive goes down into the scene tree to fine "Dice"
            
            //worldTransform is a matrix that indicates the intersection point between a ray from the touch point and a real world surface.
            //The fourth column of worldTransform (3 becuase of 0 index) indicates position of the hitTest.
            diceNode.position = SCNVector3(x: location.worldTransform.columns.3.x,
                                           y: location.worldTransform.columns.3.y + diceNode.boundingSphere.radius,
                                           z: location.worldTransform.columns.3.z) //we have to add the boundingSphere radius so the dice sits on top of the plane
            
            allDiceNodes.append(diceNode) //store all diceNode's in an array so we can spin all of them at once
            
            sceneView.scene.rootNode.addChildNode(diceNode)
            gridNode?.removeFromParentNode() //remove the visual grid after placing the first dice
            
            rollDice(forNode: diceNode)
        }
    }
    
    func rollDice(forNode dice: SCNNode) {
        
        //Generate x and z coordinates at random to simulate a random dice flip. We don't need y coordinates because rotating about the y axis leaves us with the same dice showing on top
        //We generate numbers between 1 and 4 because the dice rotates along the x and z axis with the chance of each side showing equally.
        //We then have to multiply this random number by pi/2 which is the equivalent of 90 degrees. The dice rotates 90 degrees each flip.
        let randomX = Float(arc4random_uniform(4) + 1) * (Float.pi/2)
        let randomZ = Float(arc4random_uniform(4) + 1) * (Float.pi/2)
        
        //Randomly rotate along the x and z axis 5 times over a duration of half second
        dice.runAction(SCNAction.rotateBy(x: CGFloat(randomX * 5),
                                              y: 0,
                                              z: CGFloat(randomZ * 5),
                                              duration: 0.5))
    }
    
    func rollAllDice() {
        
        if !allDiceNodes.isEmpty { //make sure we actually have dice on the plane
            for diceNode in allDiceNodes {
                rollDice(forNode: diceNode)
            }
        }
    }
    
    @IBAction func rerollDice(_ sender: UIBarButtonItem) {
        
        rollAllDice()
    }
    
    //Reroll all dice after shaking the device
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        rollAllDice()
    }
    
    @IBAction func removeAllDice(_ sender: UIBarButtonItem) {
        
        if !allDiceNodes.isEmpty {
            for diceNode in allDiceNodes {
                diceNode.removeFromParentNode()
            }
        }
    }
    
    //MARK: ARSCNViewDelegate Methods
    
    //This delegate method gets called whenever a horizontal (or vertical) surface is detected. ARKit gives that surface a width and height as an anchor
    //so that we can use this anchor to place content. The ARAnchor basically has real world coordinates of the horizontal plane we use to place objects
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return } //only keep the anchor thats of type ARPlaneAnchor. That's why this as? is an optional and returns out from the guard let if it's not
        //In other words, ARAnchor is a general type of anchor and we only want to keep an anchor that corresponds to a plane
        
        //create a plane with the x and z components of planeAnchor. Note: the height is z and not y. y is 0
        //This is because we're looking at a plane thats in front of us meaning x is left and right and z is forward and backward
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)) //convert the dimensions of the detected anchor to something we can use in SceneKit
        //NOTE: SCNPlane uses width and height form planeAnchor to create VERTICAL plane geometry. We'll transform this to a flat horizontal plane below
        
        let planeNode = SCNNode() //we need to create a node to attach the plane geometry to
        
        //create a node and set the position of that node in the center of the planeAnchor. y is 0 because it's a flat horizontal plane
        planeNode.position = SCNVector3(x: planeAnchor.center.x, y: 0, z: planeAnchor.center.z)
        
        //SCNPlane is in 3d thus x and y have values but z is 0. The plane basically extends up from a surface and we need to rotate it 90 degrees so it's flat.
        //pi is equivalent to 180 degrees so we divide by 2 (to rotate 90 degrees) and rotate it away from the camera in the negative direction (clockwise).
        //The x,y,and z paramaters specify which direction to rotate. We use 1 for x to rotate about the x axis.
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0) //angle is in radians ie 2pi radian is equivalent to 360 degrees
        
        //Create and use a material so that we can make sure the plane was created in the correct place.
        //We use a png file because png files are transparent ie so we can see through the grid
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = UIImage(named: "art.scnassets/grid.png")
        plane.materials = [gridMaterial] //assign the material to the plane geometry created above
        
        planeNode.geometry = plane //set the geometry of our planeNode to our plane
        
        gridNode = planeNode //change scope of planeNode so we can remove it (the visual grid) after rolling the first dice
        
        node.addChildNode(planeNode) //as above with spheres and boxes, we need to add the planeNode (with geometry and grid material) to the root node.
        //This delegate method gives us a blank node so that we can do that. This is the same as sceneView.scene.rootNode.addChildNode(planeNode)
        
    }
}
