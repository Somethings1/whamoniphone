//
//  ARViewContainer.swift
//  WhamApp
//
//  Created by admin on 20/3/26.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.antialiasingMode = .multisampling4X
        view.automaticallyUpdatesLighting = true
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
