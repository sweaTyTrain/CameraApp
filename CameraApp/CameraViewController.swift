//
//  ViewController.swift
//  CameraApp
//
//  Created by 이대현 on 11/18/23.
//

import AVFoundation
import UIKit
import Vision

class CameraViewController: UIViewController {
    @IBOutlet weak var previewView: PreviewView!
    
    @IBOutlet weak var isStandLabel: UILabel!
    @IBOutlet weak var isBackFrontLabel: UILabel!
    @IBOutlet weak var isKneeNarrowLabel: UILabel!
    @IBOutlet weak var isKneeWideLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .front)
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
                captureSession.canAddInput(videoDeviceInput)
        else { return }
        captureSession.addInput(videoDeviceInput)
        
        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.sessionPreset = .photo
        captureSession.addOutput(photoOutput)
        
        // Set videoDataOutput
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(videoOutput)
        
        captureSession.commitConfiguration()
        
        previewView.videoPreviewLayer.session = captureSession
        
        // start
        DispatchQueue.global().async() {
            captureSession.startRunning()
        }
    }
    
    private func convert(ciimage: CIImage) -> UIImage {
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image = UIImage(cgImage: cgImage)
        return image
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let ciimage = CIImage(cvPixelBuffer: imageBuffer)
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(ciImage: ciimage)
        // Create a new request to recognize a human body pose.
        let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)
        do {
            // Perform the body pose-detection request.
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the request: \(error).")
        }
    }
    
    func bodyPoseHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNHumanBodyPoseObservation] else {
            return
        }
        
        // Process each observation to find the recognized body pose points.
        observations.forEach { processObservation($0) }
    }
    
    func processObservation(_ observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .all) else { return }
        
        // Retrieve the CGPoints containing the normalized X and Y coordinates.
        let imagePoints: [CGPoint] = recognizedPoints.keys.compactMap {
            guard let point = recognizedPoints[$0], point.confidence > 0 else { return nil }
            return VNImagePointForNormalizedPoint(point.location, 400, 300)
        }
        // Draw the points onscreen.
        DispatchQueue.main.async {
            self.previewView.draw(points: imagePoints)
        }


        // 운동 자세 분류기
        let mlarray = try? MLMultiArray(shape: [1,6], dataType: MLMultiArrayDataType.float32)
        var isBodyRecognized = true
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              leftShoulder.confidence > 0,
              let leftHip = try? observation.recognizedPoint(.leftHip),
              leftHip.confidence > 0,
              let leftKnee = try? observation.recognizedPoint(.leftKnee),
              leftKnee.confidence > 0,
              let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              leftAnkle.confidence > 0,
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              rightShoulder.confidence > 0,
              let rightHip = try? observation.recognizedPoint(.rightHip),
              rightHip.confidence > 0,
              let rightKnee = try? observation.recognizedPoint(.rightKnee),
              rightKnee.confidence > 0,
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle),
              rightAnkle.confidence > 0
              
        else {
            DispatchQueue.main.async {
                self.statusLabel.text = "body 인식 실패"
            }
            return
        }
        // back angle right, 오른쪽 허리 각도
        mlarray?[0] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: rightShoulder.x, y: rightShoulder.y),
                center: Point(x: rightHip.x, y: rightHip.y),
                p2: Point(x: rightKnee.x, y: rightKnee.y)
            )
        )
        // back angle left, 왼쪽 허리 각도
        mlarray?[1] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: leftShoulder.x, y: leftShoulder.y),
                center: Point(x: leftHip.x, y: leftHip.y),
                p2: Point(x: leftKnee.x, y: leftKnee.y)
            )
        )
        // knee angle right, 오른쪽 무릎 각도
        mlarray?[2] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: rightAnkle.x, y: rightAnkle.y),
                center: Point(x: rightKnee.x, y: rightKnee.y),
                p2: Point(x: rightHip.x, y: rightHip.y)
            )
        )
        // knee angle left, 왼쪽 무릎 각도
        mlarray?[3] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: leftAnkle.x, y: leftAnkle.y),
                center: Point(x: leftKnee.x, y: leftKnee.y),
                p2: Point(x: leftHip.x, y: leftHip.y)
            )
        )
        // ankle knee knee_right, 발목-무릎-반대쪽 무릎 오른쪽 각도
        mlarray?[4] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: rightAnkle.x, y: rightAnkle.y),
                center: Point(x: rightKnee.x, y: rightKnee.y),
                p2: Point(x: leftKnee.x, y: leftKnee.y)
            )
        )
        // ankle knee knee_left, 발목-무릎-반대쪽 무릎 왼쪽 각도
        mlarray?[5] = NSNumber(
            value: Util.calculateAngle2d(
                p1: Point(x: leftAnkle.x, y: leftAnkle.y),
                center: Point(x: leftKnee.x, y: leftKnee.y),
                p2: Point(x: rightKnee.x, y: rightKnee.y)
            )
        )
        
        if let mlarray = mlarray {
            print("input: ")
            print(mlarray)
            let model = try? myModelReal()
            let output = try? model?.prediction(
                input: myModelRealInput(dense_input: mlarray)
            )
            print("hi output")
            if let output = output?.Identity {
                DispatchQueue.main.async {
                    self.statusLabel.text = "body 인식 성공!"
                    self.isStandLabel.text = "is_stand: " + String(describing: output[0])
                    self.isBackFrontLabel.text = "is_back_front: " + String(describing: output[1])
                    self.isKneeNarrowLabel.text = "is_knee_narrow: " + String(describing: output[2])
                    self.isKneeWideLabel.text = "is_knee_wide: " + String(describing: output[3])
                }
            }
        }
    }
}
