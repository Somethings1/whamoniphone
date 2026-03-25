//
//  VideoDetailView.swift
//  WhamApp
//
//  Created by admin on 20/3/26.
//

import SwiftUI
import AVFoundation

struct VideoDetailView: View {
    let video: VideoModel
    
    // Khởi tạo đúng class WhamAnalyzer
    @StateObject private var analyzer = WhamAnalyzer()
    
    @State private var jsonContent: String = "Đang tải dữ liệu..."
    @State private var frameCount: Int = 0
    @State private var statusMessage: String = ""
    
    @StateObject private var engine = Skeleton3DEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1. Header: Thông tin file
            VStack(alignment: .leading, spacing: 8) {
                Text("FILE: \(video.url.lastPathComponent)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("SLAM: \(video.hasGyro ? "✅ SẴN SÀNG" : "❌ THIẾU")")
                    Spacer()
                    Text("\(frameCount) FRAMES").monospaced()
                }
                .font(.headline)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            Divider()
            // Tìm chỗ hiển thị ảnh debug trong VideoDetailView, thay bằng:
            if let debugImg = analyzer.debugImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TẦM NHÌN CỦA AI (FRAME 10):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal)

                    Image(uiImage: debugImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                    Text("💡 Nếu thấy chấm đỏ đè đúng khớp xương là YOLO ngon!")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            Wham3DView(engine: engine)
                .frame(height: 300)
                .cornerRadius(15)
                .padding()

            // 2. Control Panel: Nơi ma thuật phân tích xảy ra
            VStack(spacing: 15) {
                if analyzer.isProcessing {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: analyzer.progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                        
                        HStack {
                            Text("ĐANG TRÍCH XUẤT NGƯỜI QUE (YOLOv8)...")
                            Spacer()
                            Text("\(Int(analyzer.progress * 100))%")
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                } else {
                    Button(action: {
                        Task {
                                let jsonURL = getURL(for: video.url, ext: "json")
                                await analyzer.analyze(videoURL: video.url, jsonURL: jsonURL)
                                self.statusMessage = "✅ PHÂN TÍCH XONG!"
                                loadAndFormatJSON()
                            }
                    }) {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                            Text("BẮT ĐẦU PHÂN TÍCH WHAM")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(video.hasGyro ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!video.hasGyro)
                    .padding()
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.bottom, 10)
                }
            }
            .background(Color.primary.opacity(0.03))

            Divider()

            // 3. Debug Zone: Soi nội tạng JSON
            ScrollView {
                VStack(alignment: .leading) {
                    Text("--- JSON PREVIEW (20 FRAMES ĐẦU) ---")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Text(jsonContent)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }
        .navigationTitle("Video Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAndFormatJSON()
        }
    }

    private func loadAndFormatJSON() {
        let jsonURL = getURL(for: video.url, ext: "json")

        Task {
            do {
                guard FileManager.default.fileExists(atPath: jsonURL.path) else {
                    await MainActor.run { self.jsonContent = "Lỗi: Không tìm thấy file JSON." }
                    return
                }

                let data = try Data(contentsOf: jsonURL)
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let count = jsonObject.count
                    let previewData = Array(jsonObject.prefix(20))
                    let prettyData = try JSONSerialization.data(withJSONObject: previewData, options: .prettyPrinted)
                    
                    if let prettyString = String(data: prettyData, encoding: .utf8) {
                        await MainActor.run {
                            self.frameCount = count
                            self.jsonContent = prettyString
                        }
                    }
                }
            } catch {
                await MainActor.run { self.jsonContent = "❌ Lỗi đọc JSON: \(error.localizedDescription)" }
            }
        }
    }

    private func getURL(for url: URL, ext: String) -> URL {
        let id = url.deletingPathExtension().lastPathComponent
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(id).\(ext)")
    }
}
