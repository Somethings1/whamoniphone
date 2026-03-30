//
//  VideoDetailView.swift
//  WhamApp
//

import SwiftUI
import AVKit
import SceneKit

struct VideoDetailView: View {
    let video: VideoModel
    @StateObject private var analyzer = WhamAnalyzer()

    @State private var isAnalyzedLocal: Bool

    init(video: VideoModel) {
        self.video = video
        _isAnalyzedLocal = State(initialValue: video.isAnalyzed)
    }

    var body: some View {
        VStack {
            if analyzer.isProcessing {
                ProcessingView(analyzer: analyzer)

            } else if isAnalyzedLocal {
                AnalyzedTabView(video: video)

            } else {
                NotAnalyzedView(video: video, analyzer: analyzer) {
                    self.isAnalyzedLocal = true
                }
            }
        }
        .navigationTitle(video.url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews for the 3 States

struct ProcessingView: View {
    @ObservedObject var analyzer: WhamAnalyzer

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: analyzer.progress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(.blue)
                .padding(.horizontal, 40)

            Text(analyzer.statusMessage)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)

            Text("\(Int(analyzer.progress * 100))%")
                .font(.headline)

            if let debugImg = analyzer.debugImage {
                VStack(spacing: 8) {
                    Text("YOLO 2D DEBUGGER (Frame 15):")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)

                    Image(uiImage: debugImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                    Text("If the box/dots don't align perfectly with the human, YOLO is broken.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.05))
    }
}

struct NotAnalyzedView: View {
    var video: VideoModel
    @ObservedObject var analyzer: WhamAnalyzer
    var onComplete: () -> Void

    var body: some View {
        VStack {
            // Media Playback
            VideoPlayer(player: AVPlayer(url: video.url))
                .frame(maxHeight: 400)
                .cornerRadius(12)
                .padding()

            Spacer()

            // The Trigger
            Button(action: {
                Task {
                    await analyzer.analyze(
                        videoURL: video.url,
                        gyroJsonURL: video.gyroJsonURL,
                        outputURL: video.whamOutputURL
                    )

                    if !analyzer.statusMessage.contains("Lỗi") && !analyzer.statusMessage.contains("Failed") {
                        onComplete()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "cpu")
                    Text("BẮT ĐẦU PHÂN TÍCH WHAM")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(video.hasGyro ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(16)
                .padding()
            }
            .disabled(!video.hasGyro)

            if !video.hasGyro {
                Text("⚠️ Cần dữ liệu AR (Gyro) để phân tích.")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if analyzer.statusMessage.contains("Lỗi") {
                Text(analyzer.statusMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
        }
    }
}


// MARK: - The Tab Router
struct AnalyzedTabView: View {
    let video: VideoModel
    @State private var whamData: [[String: Any]] = []

    var body: some View {
        TabView {
            // TAB 1: Video with AR overlay
            VideoOverlayView(videoURL: video.url, whamData: whamData)
                .tabItem {
                    Image(systemName: "play.tv.fill")
                    Text("Video Overlay")
                }

            // TAB 2: Pure 3D space
            Wham3DView(whamData: whamData)
                .tabItem {
                    Image(systemName: "cube.transparent.fill")
                    Text("3D World")
                }
        }
        .onAppear {
            loadJSONData()
        }
    }

    private func loadJSONData() {
        if let data = try? Data(contentsOf: video.whamOutputURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.whamData = json
        }
    }
}

// MARK: - TAB 1: The AR Overlay (Video + 3D)
struct VideoOverlayView: View {
    let videoURL: URL
    let whamData: [[String: Any]]

    @StateObject private var engine = Skeleton3DEngine()
    @State private var player: AVPlayer

    let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(videoURL: URL, whamData: [[String: Any]]) {
        self.videoURL = videoURL
        self.whamData = whamData
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()

            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: []
            )
            .background(Color.clear)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onReceive(timer) { _ in
            guard whamData.count > 0 else { return }

            let currentTime = player.currentTime().seconds
            let fps: Double = 30.0
            let frameIndex = Int(currentTime * fps)
            let safeIndex = max(0, min(frameIndex, whamData.count - 1))

            if let kp3d = whamData[safeIndex]["keypoints_3d"] as? [Float] {
                engine.applyFrameData(keypoints3D: kp3d)
            }
        }
        .onDisappear {
            player.pause()
        }
    }
}

// MARK: - TAB 2: The Pure 3D World
struct Wham3DView: View {
    let whamData: [[String: Any]]

    @StateObject private var engine = Skeleton3DEngine()
    @State private var frameIndex = 0

    var body: some View {
        ZStack {
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .background(Color.black)
            .ignoresSafeArea()

            VStack {
                Text("WHAM 3D SKELETON")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                    .padding(.top)

                Spacer()

                VStack {
                    Text("Frame: \(frameIndex)")
                        .font(.caption)
                        .foregroundColor(.white)

                    Slider(value: Binding(
                        get: { Double(frameIndex) },
                        set: { newVal in
                            frameIndex = Int(newVal)
                            updateSkeleton()
                        }
                    ), in: 0...Double(max(whamData.count - 1, 0)))
                }
                .padding()
                .background(Color.black.opacity(0.6))
            }
        }
        .onAppear {
            updateSkeleton()
        }
    }

    private func updateSkeleton() {
        guard frameIndex < whamData.count else { return }
        if let kp3d = whamData[frameIndex]["keypoints_3d"] as? [Float] {
            engine.applyFrameData(keypoints3D: kp3d)
        }
    }
}
