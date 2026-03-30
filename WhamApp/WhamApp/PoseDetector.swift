//
//  PoseDetector.swift
//  WhamApp
//

import Vision
import CoreML
import UIKit
import CoreImage

class PoseDetector {
    private var model: yolov8n_pose?

    private let ciContext = CIContext()

    init() {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            self.model = try yolov8n_pose(configuration: config)
        } catch {
            print("❌ Lỗi load YOLOv8-Pose: \(error)")
        }
    }

    struct Detection {
        let box: CGRect
        let keypoints: [CGPoint]
        let confidence: Float
    }

    func detect(pixelBuffer: CVPixelBuffer) -> [Detection] {
        guard let model = model else { return [] }

        guard let resizedBuffer = resizePixelBuffer(pixelBuffer, targetWidth: 640, targetHeight: 640) else {
            print("❌ Không thể ép size ảnh")
            return []
        }

        do {
            let input = yolov8n_poseInput(image: resizedBuffer)
            let output = try model.prediction(input: input)

            return parseYOLOOutput(output.var_1033)
        } catch {
            print("❌ YOLO Inference Error: \(error)")
            return []
        }
    }

    func detectAsync(pixelBuffer: CVPixelBuffer) async -> [Detection] {
        return detect(pixelBuffer: pixelBuffer)
    }

    private func resizePixelBuffer(_ buffer: CVPixelBuffer, targetWidth: Int, targetHeight: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: buffer)

        let scaleX = CGFloat(targetWidth) / CGFloat(CVPixelBufferGetWidth(buffer))
        let scaleY = CGFloat(targetHeight) / CGFloat(CVPixelBufferGetHeight(buffer))
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var newBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        let status = CVPixelBufferCreate(kCFAllocatorDefault, targetWidth, targetHeight, kCVPixelFormatType_32BGRA, attrs, &newBuffer)

        if status == kCVReturnSuccess, let nb = newBuffer {
            ciContext.render(resized, to: nb)
            return nb
        }
        return nil
    }

    private func parseYOLOOutput(_ output: MLMultiArray) -> [Detection] {
        var detections: [Detection] = []
        let numDetections = output.shape[2].intValue
        var bestScore: Float = 0
        var bestIdx = -1

        for i in 0..<numDetections {
            let score = output[[0, 4, i] as [NSNumber]].floatValue
            if score > 0.5 && score > bestScore {
                bestScore = score
                bestIdx = i
            }
        }

        if bestIdx != -1 {
            let cx = output[[0, 0, bestIdx] as [NSNumber]].doubleValue / 640.0
            let cy = output[[0, 1, bestIdx] as [NSNumber]].doubleValue / 640.0
            let w = output[[0, 2, bestIdx] as [NSNumber]].doubleValue / 640.0
            let h = output[[0, 3, bestIdx] as [NSNumber]].doubleValue / 640.0

            let rect = CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h)

            var kpts: [CGPoint] = []
            for j in 0..<17 {
                let kx = output[[0, 5 + j*3, bestIdx] as [NSNumber]].doubleValue / 640.0
                let ky = output[[0, 5 + j*3 + 1, bestIdx] as [NSNumber]].doubleValue / 640.0
                kpts.append(CGPoint(x: kx, y: ky))
            }

            detections.append(Detection(box: rect, keypoints: kpts, confidence: bestScore))
        }

        return detections
    }
}
