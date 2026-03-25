//
//  PoseDetector.swift
//  WhamApp
//
//  Created by admin on 21/3/26.
//

import Vision
import UIKit

class PoseDetector {
    // Không cần load model MLPackage nữa, dùng hàng có sẵn của hệ điều hành
    
    func detect(pixelBuffer: CVPixelBuffer, completion: @escaping ([[String: Any]]) -> Void) {
        // 1. Tạo request bắt người của Apple
        let request = VNDetectHumanBodyPoseRequest { request, error in
            guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
                completion([])
                return
            }
            
            var allPeople: [[String: Any]] = []
            
            for observation in observations {
                // Lấy tất cả các khớp xương có sẵn
                guard let recognizedPoints = try? observation.recognizedPoints(.all) else { continue }
                
                var personDict: [String: [Double]] = [:]
                
                for (jointName, point) in recognizedPoints where point.confidence > 0.1 {
                    // Lột lớp 1: JointName -> VNRecognizedPointKey
                    // Lột lớp 2: VNRecognizedPointKey -> String
                    let finalKeyString = jointName.rawValue.rawValue
                    
                    personDict[finalKeyString] = [
                        Double(point.location.x),
                        Double(1 - point.location.y),
                        Double(point.confidence)
                    ]
                }
                
                if !personDict.isEmpty {
                    allPeople.append(personDict)
                }
            }
            completion(allPeople)
        }

        // 2. Chạy request
        // Vì mày đã sửa Manager quay đúng chiều Portrait, ở đây dùng .up là chuẩn
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }

    // Hàm Async cho thằng WhamAnalyzer (Swift 6)
    func detectAsync(pixelBuffer: CVPixelBuffer) async -> [[String: Any]] {
        await withCheckedContinuation { continuation in
            self.detect(pixelBuffer: pixelBuffer) { results in
                continuation.resume(returning: results)
            }
        }
    }
}
