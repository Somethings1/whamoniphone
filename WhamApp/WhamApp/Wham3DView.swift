//
//  Wham3DView.swift
//  WhamApp
//
//  Created by admin on 21/3/26.
//

import SwiftUI
import SceneKit

struct Wham3DView: View {
    @ObservedObject var engine: Skeleton3DEngine
    
    var body: some View {
        ZStack {
            // Đây là cái cửa sổ nhìn vào thế giới 3D
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            
            VStack {
                Text("WHAM 3D VISUALIZER")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(.black.opacity(0.7))
                    .foregroundColor(.green)
                Spacer()
            }
        }
    }
}
