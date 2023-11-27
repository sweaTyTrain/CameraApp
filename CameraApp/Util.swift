//
//  Util.swift
//  CameraApp
//
//  Created by 이대현 on 11/27/23.
//

import Foundation

struct Point {
    let x: Double
    let y: Double
}

class Util {
    static func calculateAngle2d(p1: Point, center: Point, p2: Point) -> Double {
        let v1 = CGVector(dx: p1.x - center.x, dy: p1.y - center.y)
        let v2 = CGVector(dx: p2.x - center.x, dy: p2.y - center.y)
        
        let angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx)
        
        var degree = angle * CGFloat(180.0 / .pi)
        if degree < 0 { degree += 360.0 }
        return degree
    }
}
