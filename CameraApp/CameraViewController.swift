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
        print("captureOutput")
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
        print("bodyPoseHandler")
        guard let observations =
                request.results as? [VNHumanBodyPoseObservation] else {
            return
        }
        
        // Process each observation to find the recognized body pose points.
        observations.forEach { processObservation($0) }
    }
    
    func processObservation(_ observation: VNHumanBodyPoseObservation) {
        print("processObservation")
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .all) else { return }
        
        // Retrieve the CGPoints containing the normalized X and Y coordinates.
        let imagePoints: [CGPoint] = recognizedPoints.keys.compactMap {
            guard let point = recognizedPoints[$0], point.confidence > 0 else { return nil }
            return VNImagePointForNormalizedPoint(point.location, 400, 300)
        }
        print(imagePoints.count)
        // Draw the points onscreen.
        self.previewView.draw(points: imagePoints)
    }
}
