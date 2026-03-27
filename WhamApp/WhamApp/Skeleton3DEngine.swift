//
//  Skeleton3DEngine.swift
//  WhamApp
//

import SceneKit

class Skeleton3DEngine: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    
    private var jointNodes: [SCNNode] = []
    private var boneNodes: [SCNNode] = []
    
    // THE FIX: The COCO 17-Joint Layout (Matches YOLOv8 exactly)
    // 0: Nose, 1: L_Eye, 2: R_Eye, 3: L_Ear, 4: R_Ear
    // 5: L_Shoulder, 6: R_Shoulder, 7: L_Elbow, 8: R_Elbow, 9: L_Wrist, 10: R_Wrist
    // 11: L_Hip, 12: R_Hip, 13: L_Knee, 14: R_Knee, 15: L_Ankle, 16: R_Ankle
    private let boneConnections: [(Int, Int)] = [
        // Face/Head
        (0, 1), (1, 3),       // Nose to L_Eye to L_Ear
        (0, 2), (2, 4),       // Nose to R_Eye to R_Ear
        
        // Torso (Connecting Shoulders and Hips)
        (5, 6),               // L_Shoulder to R_Shoulder
        (11, 12),             // L_Hip to R_Hip
        (5, 11),              // L_Shoulder to L_Hip
        (6, 12),              // R_Shoulder to R_Hip
        
        // Pseudo-Neck (Connect Nose to midpoint of shoulders)
        // Since COCO has no neck joint, we anchor the head to the shoulders
        (0, 5), (0, 6),
        
        // Left Arm
        (5, 7), (7, 9),       // L_Shoulder to L_Elbow to L_Wrist
        
        // Right Arm
        (6, 8), (8, 10),      // R_Shoulder to R_Elbow to R_Wrist
        
        // Left Leg
        (11, 13), (13, 15),   // L_Hip to L_Knee to L_Ankle
        
        // Right Leg
        (12, 14), (14, 16)    // R_Hip to R_Knee to R_Ankle
    ]
    
    init() {
        setupScene()
    }
    
    private func setupScene() {
        scene.background.contents = UIColor.clear
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0.5, z: 4.5)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 5, 5)
        scene.rootNode.addChildNode(lightNode)
        
        // 17 Spheres for joints
        for _ in 0..<17 {
            let sphere = SCNSphere(radius: 0.03)
            sphere.firstMaterial?.diffuse.contents = UIColor.green
            let node = SCNNode(geometry: sphere)
            jointNodes.append(node)
            scene.rootNode.addChildNode(node)
        }
        
        // Cylinders for bones
        for _ in boneConnections {
            let bone = SCNCylinder(radius: 0.008, height: 1.0)
            bone.firstMaterial?.diffuse.contents = UIColor.lightGray
            let node = SCNNode(geometry: bone)
            boneNodes.append(node)
            scene.rootNode.addChildNode(node)
        }
    }
    
    func applyFrameData(keypoints3D: [Float]) {
        guard keypoints3D.count == 51 else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.03
        
        var positions: [SCNVector3] = []
        for i in 0..<17 {
            let x = keypoints3D[i * 3]
            let y = keypoints3D[i * 3 + 1]
            let z = keypoints3D[i * 3 + 2]
            
            let pos = SCNVector3(x, -y, -z)
            positions.append(pos)
            jointNodes[i].position = pos
        }
        
        for (index, connection) in boneConnections.enumerated() {
            let start = positions[connection.0]
            let end = positions[connection.1]
            let boneNode = boneNodes[index]
            
            let dir = simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
            let height = length(dir)
            
            if height > 0.001 {
                boneNode.isHidden = false
                if let cylinder = boneNode.geometry as? SCNCylinder {
                    cylinder.height = CGFloat(height)
                }
                
                boneNode.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
                
                let defaultUp = simd_float3(0, 1, 0)
                let normalizedDir = normalize(dir)
                let axis = cross(defaultUp, normalizedDir)
                let dotProduct = dot(defaultUp, normalizedDir)
                
                if length(axis) > 0.001 {
                    let angle = acos(dotProduct)
                    boneNode.simdOrientation = simd_quatf(angle: angle, axis: normalize(axis))
                }
            } else {
                boneNode.isHidden = true
            }
        }
        
        SCNTransaction.commit()
    }
}
