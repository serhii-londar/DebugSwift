//
//  RouteSimulation.swift
//  DebugSwift
//
//  Created by Cline on 14/02/24.
//

import CoreLocation
import Foundation

struct RouteSimulation {
    enum Speed: String, CaseIterable {
        case walk = "Walking"
        case run = "Running"
        case drive = "Driving"
        case flight = "Flying"
        case custom = "Custom"
        
        var metersPerSecond: Double {
            switch self {
            case .walk: return 1.4  // ~5 km/h
            case .run: return 3.0   // ~11 km/h
            case .drive: return 13.9 // ~50 km/h
            case .flight: return 250.0 // ~900 km/h
            case .custom: return 0.0 // Set by user
            }
        }
    }
    
    var speed: Speed = .walk
    var customSpeed: Double = 0.0
    var locations: [CLLocation] = []
    var isSimulating: Bool = false
    var currentLocationIndex: Int = 0
    
    var effectiveSpeed: Double {
        speed == .custom ? customSpeed : speed.metersPerSecond
    }
}

extension RouteSimulation {
    enum Constants {
        static let simulatedRouteKey = "_simulatedRoute"
        static let simulatedSpeedKey = "_simulatedSpeed"
        static let simulatedCustomSpeedKey = "_simulatedCustomSpeed"
        static let simulatedIsActiveKey = "_simulatedRouteIsActive"
    }
}
