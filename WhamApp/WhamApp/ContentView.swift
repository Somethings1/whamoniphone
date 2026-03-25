//
//  ContentView.swift
//  WhamApp
//
//  Created by admin on 20/3/26.
//

import SwiftUI

struct MainCameraView: View {
    // Chuyển sang dùng ARWhamManager để lấy dữ liệu SLAM
    @StateObject var manager = ARWhamManager()
    @State private var isShowingLibrary = false

    var body: some View {
        ZStack {
            // Lớp nền ARKit - Cửa sổ nhìn vào không gian 3D
            ARViewContainer(session: manager.session)
                .ignoresSafeArea()
            
            // Lớp Overlay: Timer (Chỉ hiện khi đang quay)
            if manager.isRecording {
                VStack {
                    Text(manager.formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    Spacer()
                }
            }

            // Lớp Overlay: Control Panel (Nút Lib và Nút Record)
            VStack {
                Spacer()
                
                // Trạng thái ARKit (Giúp mày biết khi nào SLAM đã sẵn sàng)
                // WHAM cần World Tracking ổn định để không trượt chân
                if !manager.isRecording {
                    Text("Di chuyển iPhone để calibrate SLAM...")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(5)
                        .padding(.bottom, 10)
                }

                HStack(spacing: 40) {
                    // Nút mở Thư viện (Hiện ảnh của video mới nhất)
                    Button(action: { isShowingLibrary = true }) {
                        Group {
                            if let thumb = manager.lastThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.black.opacity(0.5)
                            }
                        }
                        .frame(width: 65, height: 65)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2))
                        .clipped()
                    }
                    
                    // Nút Record chính giữa
                    Button(action: {
                        manager.toggleRecording()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            if manager.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: 35, height: 35)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 68, height: 68)
                            }
                        }
                    }
                    
                    // Nút Reset Tracking (Phòng trường hợp SLAM bị ngáo)
                    Button(action: { manager.resetTracking() }) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        // Vuốt lên để xem thư viện video đã quay
        .sheet(isPresented: $isShowingLibrary, onDismiss: { manager.resume() }) {
            VideoLibraryView()
                .onAppear{ manager.pause() }
        }
    }
}

// Cấu trúc mặc định của file ContentView trong Xcode
struct ContentView: View {
    var body: some View {
        MainCameraView()
    }
}
