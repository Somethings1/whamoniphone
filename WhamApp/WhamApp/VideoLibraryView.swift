//
//  VideoLibraryView.swift
//  WhamApp
//
//  Created by admin on 20/3/26.
//

import SwiftUI
import AVFoundation

struct VideoLibraryView: View {
    @State private var videos: [VideoModel] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(videos) { video in
                NavigationLink(destination: VideoDetailView(video: video)) {
                    HStack {
                        // Thumbnail (Lấy từ file video thực tế)
                        VideoThumbnailView(url: video.url)
                            .frame(width: 80, height: 60)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading) {
                            Text(video.url.lastPathComponent)
                                .font(.system(size: 14, design: .monospaced))
                                .lineLimit(1)
                            Text("Gyro: \(video.hasGyro ? "✅ Sẵn sàng" : "❌ Thiếu")")
                                .font(.caption)
                                .foregroundColor(video.hasGyro ? .green : .red)
                        }
                        
                        Spacer()
                        
                        if video.isAnalyzed {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Thư viện WHAM")
            .toolbar {
                Button("Đóng") { dismiss() }
            }
            .onAppear(perform: loadVideos)
        }
    }
    
    func loadVideos() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            // 1. Lấy danh sách file kèm theo thuộc tính ngày tạo
            let files = try FileManager.default.contentsOfDirectory(at: docs,
                                                                    includingPropertiesForKeys: [.creationDateKey],
                                                                    options: .skipsHiddenFiles)
            
            // 2. Lọc file mp4 và SẮP XẾP GIẢM DẦN (Mới nhất lên đầu)
            let sortedVideoURLs = files.filter { $0.pathExtension == "mp4" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2 // Dấu '>' là để thằng mới hơn đứng trước
                }
            
            // 3. Map sang VideoModel của mày
            self.videos = sortedVideoURLs.map { url in
                let idString = url.deletingPathExtension().lastPathComponent
                let jsonURL = docs.appendingPathComponent("\(idString).json")
                let analyzedURL = docs.appendingPathComponent("\(idString)_out.mp4")
                
                return VideoModel(
                    id: UUID(uuidString: idString) ?? UUID(),
                    url: url,
                    hasGyro: FileManager.default.fileExists(atPath: jsonURL.path),
                    isAnalyzed: FileManager.default.fileExists(atPath: analyzedURL.path)
                )
            }
        } catch {
            print("❌ Lỗi sắp xếp thư viện: \(error)")
        }
    }
}

// Model cập nhật để check Gyro
struct VideoModel: Identifiable {
    let id: UUID
    let url: URL
    let hasGyro: Bool
    let isAnalyzed: Bool
}

// 1. Cái này để hiện cái hình nhỏ nhỏ trong danh sách
struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        Group {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black // Hiện màu đen trong lúc chờ load
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    func generateThumbnail() {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            if let cgImage = cgImage {
                DispatchQueue.main.async {
                    self.thumbnail = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}
