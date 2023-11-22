//
//  PreviewView.swift
//  CameraApp
//
//  Created by 이대현 on 11/18/23.
//

import AVFoundation
import UIKit

class PreviewView: UIView {
    var prevLayer: [CALayer] = []
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    func draw(points: [CGPoint]) {
        self.prevLayer.forEach { $0.removeFromSuperlayer() }
        self.prevLayer.removeAll()
        for point in points {
            let circlePath = UIBezierPath(arcCenter: CGPoint(x: self.frame.width - point.y, y: point.x), radius: CGFloat(2), startAngle: CGFloat(0), endAngle: CGFloat(Double.pi * 2), clockwise: true)
                
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = circlePath.cgPath
                
            // Change the fill color
            shapeLayer.fillColor = UIColor.clear.cgColor
            // You can change the stroke color
            shapeLayer.strokeColor = UIColor.red.cgColor
            // You can change the line width
            shapeLayer.lineWidth = 3.0
                
            self.layer.addSublayer(shapeLayer)
            self.prevLayer.append(shapeLayer)
        }
        self.setNeedsDisplay()
    }
}
