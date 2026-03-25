//
//  WhamAnalyzer.swift
//  WhamApp
//
//  Created by admin on 21/3/26.
//

import Foundation
import AVFoundation
import Vision
import UIKit

@MainActor
class WhamAnalyzer: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var debugImage: UIImage?
    
    private let poseDetector = PoseDetector()

    func analyze(videoURL: URL, jsonURL: URL) async {
        self.isProcessing = true
        self.progress = 0
        
        let asset = AVAsset(url: videoURL)
        do {
            let reader = try AVAssetReader(asset: asset)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return }
            
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ])
            reader.add(output)
            reader.startReading()
            
            let data = try Data(contentsOf: jsonURL)
            guard var slmArray = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] else { return }
            
            var localIdx = 0
            while reader.status == .reading, let buffer = output.copyNextSampleBuffer() {
                if let pix = CMSampleBufferGetImageBuffer(buffer) {
                    let kpts = await poseDetector.detectAsync(pixelBuffer: pix)
                    
                    if localIdx < slmArray.count {
                        slmArray[localIdx]["kpts"] = kpts
                    }
                    
                    // DEBUG: Vẽ người que lên frame thứ 10 để check
                    if localIdx == 10 {
                        self.debugImage = self.drawSkeletonOnFrame(pixelBuffer: pix, kpts: kpts)
                    }
                    
                    localIdx += 1
                    self.progress = Double(localIdx) / Double(slmArray.count)
                }
            }
            
            let finalData = try JSONSerialization.data(withJSONObject: slmArray, options: .prettyPrinted)
            try finalData.write(to: jsonURL)
            self.isProcessing = false
        } catch {
            self.isProcessing = false
        }
    }

    // Hàm này sẽ vẽ các điểm xanh đỏ lên ảnh để mày biết YOLO có "ngáo" không
    private func drawSkeletonOnFrame(pixelBuffer: CVPixelBuffer, kpts: [[String: Any]]) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        // Tạo ảnh chuẩn hướng .right để nó dựng đứng lên
        let baseImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        let size = baseImage.size
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        baseImage.draw(in: CGRect(origin: .zero, size: size))
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return baseImage }
        
        for person in kpts {
            for (key, value) in person {
                if let coords = value as? [Double], coords.count >= 2 {
                    // Tọa độ Vision trả về là normalized (0 -> 1)
                    // Nhưng nó tính trên khung hình CHƯA XOAY
                    // Nên khi vẽ lên ảnh ĐÃ XOAY (.right), ta phải hoán đổi X và Y
                    
                    let x = CGFloat(coords[0]) * size.width
                    let y = CGFloat(coords[1]) * size.height
                    
                    // Vẽ chấm đỏ to tổ chảng cho mày dễ thấy
                    ctx.setFillColor(UIColor.red.cgColor)
                    ctx.setStrokeColor(UIColor.white.cgColor)
                    ctx.setLineWidth(2)
                    
                    let rect = CGRect(x: x - 15, y: y - 15, width: 30, height: 30)
                    ctx.fillEllipse(in: rect)
                    ctx.strokeEllipse(in: rect)
                    
                    print("📍 Drawing point \(key) at: \(x), \(y)")
                }
            }
        }
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
