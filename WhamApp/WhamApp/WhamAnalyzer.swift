//
//  WhamAnalyzer.swift
//  WhamApp
//

import Foundation
import AVFoundation
import CoreML
import UIKit

@MainActor
class WhamAnalyzer: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var statusMessage: String = ""
    @Published var debugImage: UIImage?
    
    private let ciContext = CIContext()
    
    init() {}

    func analyze(videoURL: URL, gyroJsonURL: URL, outputURL: URL) async {
        self.isProcessing = true
        self.progress = 0
        self.statusMessage = "Đang chuẩn bị dữ liệu..."
        
        do {
            try await Task.detached(priority: .userInitiated) {
                let gyroData = try self.loadGyroData(from: gyroJsonURL)
                let asset = AVURLAsset(url: videoURL)
                let reader = try AVAssetReader(asset: asset)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else { return }

                // Grab the rotation sticky note left by the iPhone camera
                let transform = try await track.load(.preferredTransform)

                let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ])
                reader.add(output)
                reader.startReading()
                
                var allFeatures: [MLMultiArray] = []
                var allKeypoints: [MLMultiArray] = []
                var frameIdx = 0

                await MainActor.run { self.statusMessage = "Đang nạp AI Thị giác..." }
                var poseDetector: PoseDetector? = PoseDetector()
                var fastViT: _FastViT? = try _FastViT(configuration: MLModelConfiguration())
                
                await MainActor.run { self.statusMessage = "Đang trích xuất (Stage 1/2)..." }
                
                // ==========================================
                // STAGE 1: YOLO + FastViT Extraction
                // ==========================================
                while reader.status == .reading {
                    guard let buffer = output.copyNextSampleBuffer() else { break }
                    
                    try autoreleasepool {
                        if let rawPix = CMSampleBufferGetImageBuffer(buffer) {
                            
                            // THE FIX: Safely rotate the image upright using Core Image Orientations
                            let orientation = self.getVideoOrientation(from: transform)
                            let ciImage = CIImage(cvPixelBuffer: rawPix).oriented(orientation)
                            
                            let realWidth = ciImage.extent.width
                            let realHeight = ciImage.extent.height
                            
                            var uprightPix: CVPixelBuffer?
                            CVPixelBufferCreate(nil, Int(realWidth), Int(realHeight), kCVPixelFormatType_32BGRA, nil, &uprightPix)
                            
                            if let pix = uprightPix {
                                // Draw the upright image into the new buffer
                                self.ciContext.render(ciImage, to: pix)
                                
                                if let person = poseDetector?.detect(pixelBuffer: pix).first {
                                    
                                    // VISUAL DEBUGGER (Frame 15)
                                    if frameIdx == 15 {
                                        let debugImg = self.drawYOLO_DEBUG(pixelBuffer: pix, detection: person)
                                        Task { @MainActor in self.debugImage = debugImg }
                                    }
                                    
                                    // BBox in real upright pixels
                                    let realPixelBox = CGRect(
                                        x: person.box.origin.x * realWidth,
                                        y: person.box.origin.y * realHeight,
                                        width: person.box.width * realWidth,
                                        height: person.box.height * realHeight
                                    )
                                    
                                    // 1. FastViT (on the upright image)
                                    if let cropped = self.cropPixelBuffer(pix, to: realPixelBox) {
                                        let vitInput = _FastViTInput(image_input: cropped)
                                        if let vitOutput = try fastViT?.prediction(input: vitInput) {
                                            let reshapedFeat = try self.reshapeTo1x1x1024(vitOutput.features_1024)
                                            allFeatures.append(reshapedFeat)
                                        } else {
                                            allFeatures.append(try self.zeros([1, 1, 1024]))
                                        }
                                    }
                                    
                                    // 2. WHAM 2D Keypoints (Normalized -1 to 1)
                                    let kpArray = try self.zeros([1, 1, 37])
                                    for (j, kp) in person.keypoints.enumerated() {
                                        kpArray[[0, 0, j*2] as [NSNumber]] = NSNumber(value: Float(kp.x * 2.0 - 1.0))
                                        kpArray[[0, 0, j*2+1] as [NSNumber]] = NSNumber(value: Float(kp.y * 2.0 - 1.0))
                                    }
                                    kpArray[[0, 0, 34] as [NSNumber]] = NSNumber(value: Float(person.box.midX * 2.0 - 1.0))
                                    kpArray[[0, 0, 35] as [NSNumber]] = NSNumber(value: Float(person.box.midY * 2.0 - 1.0))
                                    kpArray[[0, 0, 36] as [NSNumber]] = NSNumber(value: Float(person.box.width * 2.0))
                                    
                                    allKeypoints.append(kpArray)
                                    
                                } else {
                                    allFeatures.append(try self.zeros([1, 1, 1024]))
                                    allKeypoints.append(try self.zeros([1, 1, 37]))
                                }
                            }
                        }
                    }
                    
                    frameIdx += 1
                    let currentProgress = (Double(frameIdx) / Double(max(gyroData.count, 1))) * 0.5
                    await MainActor.run { self.progress = currentProgress }
                }
                
                await MainActor.run { self.statusMessage = "Đang dọn dẹp RAM..." }
                poseDetector = nil
                fastViT = nil
                try await Task.sleep(nanoseconds: 3_000_000_000)
                
                // ==========================================
                // STAGE 2: WHAM Inference
                // ==========================================
                await MainActor.run { self.statusMessage = "Đang nạp AI WHAM..." }
                let whamConfig = MLModelConfiguration()
                whamConfig.computeUnits = .all

                guard let initModel = try? WHAM_I(configuration: whamConfig),
                      let stepModel = try? WHAM_S(configuration: whamConfig) else {
                    await MainActor.run { self.statusMessage = "Lỗi nạp Core ML Models!" }
                    return
                }

                await MainActor.run { self.statusMessage = "Đang nội suy 3D (Stage 2/2)..." }
                var whamResults: [[String: Any]] = []
                let totalFrames = allFeatures.count
                
                let init_kp = try self.zeros([1, 1, 88])
                let init_smpl = try self.zeros([1, 1, 144])
                let initOutput = try initModel.prediction(init_kp: init_kp, init_smpl: init_smpl)
                
                var current_h_enc = initOutput.h_enc
                var current_c_enc = initOutput.c_enc
                var current_h_traj = initOutput.h_traj
                var current_c_traj = initOutput.c_traj
                var current_h_dec = initOutput.h_dec
                var current_c_dec = initOutput.c_dec
                
                var prev_kp3d = try self.zeros([1, 1, 51])
                var prev_root = try self.zeros([1, 1, 6])
                var prev_pose = init_smpl
                let cam_a_step = try self.zeros([1, 1, 6])

                for i in 0..<totalFrames {
                    try autoreleasepool {
                        let stepInput = WHAM_SInput(
                            x_step: allKeypoints[i],
                            cam_a_step: cam_a_step,
                            prev_kp3d: prev_kp3d,
                            prev_root: prev_root,
                            prev_pose: prev_pose,
                            h_enc_in: current_h_enc,
                            c_enc_in: current_c_enc,
                            h_traj_in: current_h_traj,
                            c_traj_in: current_c_traj,
                            h_dec_in: current_h_dec,
                            c_dec_in: current_c_dec
                        )
                        
                        let stepOutput = try stepModel.prediction(input: stepInput)
                        
                        current_h_enc = stepOutput.h_enc_out
                        current_c_enc = stepOutput.c_enc_out
                        current_h_traj = stepOutput.h_traj_out
                        current_c_traj = stepOutput.c_traj_out
                        current_h_dec = stepOutput.h_dec_out
                        current_c_dec = stepOutput.c_dec_out
                        
                        prev_kp3d = stepOutput.pred_kp3d
                        prev_root = stepOutput.pred_root
                        prev_pose = stepOutput.pred_pose
                        
                        whamResults.append([
                            "frame": i,
                            "pose_6d": self.toFloatArray(stepOutput.pred_pose),
                            "root_orient": self.toFloatArray(stepOutput.pred_root),
                            "keypoints_3d": self.toFloatArray(stepOutput.pred_kp3d)
                        ])
                    }
                    
                    let currentProgress = 0.5 + (Double(i) / Double(totalFrames)) * 0.5
                    await MainActor.run { self.progress = currentProgress }
                }
                
                let finalData = try JSONSerialization.data(withJSONObject: whamResults)
                try finalData.write(to: outputURL)
                
            }.value
            
            self.statusMessage = "✅ PHÂN TÍCH THÀNH CÔNG!"
            self.isProcessing = false
            
        } catch {
            print("❌ Analysis Failed: \(error)")
            self.statusMessage = "❌ Lỗi: \(error.localizedDescription)"
            self.isProcessing = false
        }
    }

    // --- HELPER FUNCTIONS ---
    
    // Translates the AVAsset transform into a clean CoreImage Orientation
    nonisolated private func getVideoOrientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            return .right // Portrait
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            return .left // Portrait Upside Down
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            return .up // Landscape Right
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            return .down // Landscape Left
        }
        return .right // Fallback default
    }
    
    nonisolated private func toFloatArray(_ arr: MLMultiArray) -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(arr.count)
        for i in 0..<arr.count { result.append(arr[i].floatValue) }
        return result
    }
    
    nonisolated private func reshapeTo1x1x1024(_ arr: MLMultiArray) throws -> MLMultiArray {
        let newArr = try MLMultiArray(shape: [1, 1, 1024], dataType: .float32)
        for i in 0..<1024 { newArr[[0, 0, i] as [NSNumber]] = arr[[0, i] as [NSNumber]] }
        return newArr
    }

    nonisolated private func zeros(_ shape: [NSNumber]) throws -> MLMultiArray {
        return try MLMultiArray(shape: shape, dataType: .float32)
    }

    nonisolated private func cropPixelBuffer(_ buffer: CVPixelBuffer, to rect: CGRect) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: buffer).cropped(to: rect)
        let moveOrigin = CGAffineTransform(translationX: -rect.origin.x, y: -rect.origin.y)
        let scaleX = 256.0 / rect.width
        let scaleY = 256.0 / rect.height
        let scale = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let finalTransform = moveOrigin.concatenating(scale)
        let resized = ciImage.transformed(by: finalTransform)
        
        var newBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 256, 256, kCVPixelFormatType_32BGRA, nil, &newBuffer)
        if let nb = newBuffer { ciContext.render(resized, to: nb) }
        return newBuffer
    }
    
    nonisolated private func loadGyroData(from url: URL) throws -> [[String: Any]] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    // --- YOLO 2D VISUAL DEBUGGER ---
    nonisolated private func drawYOLO_DEBUG(pixelBuffer: CVPixelBuffer, detection: PoseDetector.Detection) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let realBox = CGRect(
            x: detection.box.origin.x * width,
            y: detection.box.origin.y * height,
            width: detection.box.width * width,
            height: detection.box.height * height
        )
        
        ctx.setStrokeColor(UIColor.red.cgColor)
        ctx.setLineWidth(4.0)
        ctx.stroke(realBox)
        
        ctx.setFillColor(UIColor.green.cgColor)
        for kp in detection.keypoints {
            let realX = kp.x * width
            let realY = kp.y * height
            ctx.fillEllipse(in: CGRect(x: realX - 6, y: realY - 6, width: 12, height: 12))
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage
    }
}
