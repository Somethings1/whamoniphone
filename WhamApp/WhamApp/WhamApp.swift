//
//  WhamApp.swift
//  WhamApp
//
//  Created by admin on 20/3/26.
//

import SwiftUI

@main
struct WhamApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                MainCameraView()
                    .tabItem {
                        Label("AR Camera", systemImage: "camera.viewfinder")
                    }
                
                OfflineProcessView()
                    .tabItem {
                        Label("Video Thầy", systemImage: "folder.badge.gearshape")
                    }
            }
        }
    }
}
