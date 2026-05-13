//
//  OfflineProcessView.swift
//  WhamApp
//
//  Created by Long Trung on 11/5/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct OfflineProcessView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @StateObject private var analyzer = WhamAnalyzer()
    
    @State private var statusText: String = "Sẵn sàng nhận hàng từ thầy..."
    @State private var outputMessage: String = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Text("XỬ LÝ VIDEO OFFINE")
                .font(.title2.bold())
            
            if analyzer.isProcessing {
                ProcessingView(analyzer: analyzer)
            } else {
                Text(statusText)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("CHỌN VIDEO TỪ MÁY")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        await processSelectedVideo(item: newItem)
                    }
                }
                
                if !outputMessage.isEmpty {
                    Text(outputMessage)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                }
            }
            Spacer()
        }
        .padding(.top, 40)
    }
    
    private func processSelectedVideo(item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        statusText = "Đang copy video từ Photos ra Documents..."
        
        // 1. Lấy URL của video từ Photos (Nó thường là URL tạm)
        guard let videoData = try? await item.loadTransferable(type: Data.self) else {
            statusText = "Lỗi: Đéo đọc được video từ Photos."
            return
        }
        
        // 2. Định tuyến các file vào thẳng thư mục Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoName = "Offline_\(UUID().uuidString.prefix(5))"
        
        let videoURL = docs.appendingPathComponent("\(videoName).mp4")
        let fakeGyroURL = docs.appendingPathComponent("\(videoName).json") // File gyro giả
        let outputJSONURL = docs.appendingPathComponent("\(videoName)_wham_output.json")
        
        do {
            // Ghi file video cứng ra Documents
            try videoData.write(to: videoURL)
            // Ghi mảng rỗng [] cho file Gyro để khỏi lỗi
            try "[]".data(using: .utf8)?.write(to: fakeGyroURL)
            
            statusText = "Đã lưu vào Documents. Bắt đầu đẩy vào WHAM..."
            
            // 3. Gọi con quái vật WhamAnalyzer
            await analyzer.analyze(
                videoURL: videoURL,
                gyroJsonURL: fakeGyroURL,
                outputURL: outputJSONURL
            )
            
            if !analyzer.statusMessage.contains("Lỗi") {
                outputMessage = "XONG! File kết quả:\n\(outputJSONURL.lastPathComponent)"
                statusText = "Mở app 'Tệp' (Files) trên iPhone lên mà lấy file."
            } else {
                statusText = "Tạch cmnr: \(analyzer.statusMessage)"
            }
            
        } catch {
            statusText = "Lỗi IO: \(error.localizedDescription)"
        }
    }
}
