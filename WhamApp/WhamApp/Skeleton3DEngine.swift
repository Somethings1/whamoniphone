//
//  Skeleton3DEngine.swift
//  WhamApp
//
//  Created by admin on 21/3/26.
//

import SceneKit
import Vision

class Skeleton3DEngine: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var jointNodes: [String: SCNNode] = [:]
    
    init() {
        setupScene()
    }
    
    private func setupScene() {
        scene.background.contents = UIColor.black
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5) // Đứng xa ra để nhìn toàn cảnh
        scene.rootNode.addChildNode(cameraNode)
        
        // Tạo sẵn các "khớp xương" là các hình cầu nhỏ
        let joints = ["nose", "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
                      "left_wrist", "right_wrist", "left_hip", "right_hip",
                      "left_knee", "right_knee", "left_ankle", "right_ankle"]
        
        for joint in joints {
            let node = SCNNode(geometry: SCNSphere(radius: 0.05))
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            jointNodes[joint] = node
            scene.rootNode.addChildNode(node)
        }
    }
    
    // Cập nhật vị trí người que từ dữ liệu 2D sang 3D
    func updatePose(kpts: [String: [Double]]) {
        // Tính toán "Độ sâu giả định" (Z)
        // Nếu khoảng cách vai rộng -> người ở gần (Z nhỏ)
        var depth: Float = 0.0
        if let ls = kpts["left_shoulder"], let rs = kpts["right_shoulder"] {
            let dist = sqrt(pow(ls[0] - rs[0], 2) + pow(ls[1] - rs[1], 2))
            depth = Float(1.0 / dist) // Công thức "bốc phét" nhưng hiệu quả
        }
        
        for (name, node) in jointNodes {
            if let data = kpts[name] {
                // Chuyển tọa độ 0->1 của Vision sang hệ 3D của SceneKit
                let x = Float(data[0] - 0.5) * 2.0
                let y = Float(0.5 - data[1]) * 3.5
                let z = -depth // Đẩy ra xa theo trục Z
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.05
                node.position = SCNVector3(x, y, z)
                SCNTransaction.commit()
            }
        }
    }
}
